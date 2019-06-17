#
# register DNS record
#
register_dns_record() {
  ENVIRONMENT=$1
  ARGOCD_SERVER=$1
  #
  # create a ResourceRecordSet in the hosted zone in route 53 to point to argocd / default nginx-ingress
  #
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == 'raincove.io.'].Id" --output text)
  echo -e "hosted-zone-id resolved to ${HOSTED_ZONE_ID}"
  NGINX_PUBLIC_IP=$(kubectl get svc -n ingress-nginx -o jsonpath='{.items[].status.loadBalancer.ingress[].ip}')
  cat <<EOF > route53-request.json
  {
    "Comment": "CREATE/DELETE/UPSERT a record ",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "${ENVIRONMENT}.raincove.io",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${NGINX_PUBLIC_IP}"
            }
          ]
        }
      },
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "argocd-${ENVIRONMENT}.raincove.io",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${ARGOCD_SERVER}"
            }
          ]
        }
      }    
    ]
  }
EOF
  echo -e "Adding A records for hosted-zone-id=${HOSTED_ZONE_ID} ..."
  aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch file://route53-request.json

  rm route53-request.json
}

#
# Install argocd and configure it
#
install_and_configure_argocd() {
  #
  # install argocd
  #
  echo -e "Installing argocd to the cluster"
  kubectl create namespace argocd
  kubectl apply \
      -n argocd \
      -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

  kubectl patch svc argocd-server \
      -n argocd \
      -p '{"spec": {"type": "LoadBalancer"}}'

  ARGOCD_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)

  echo -e "Waiting for argocd-server to acquire an external IP address"
  while [ -z "$ARGOCD_SERVER" ]; do
      ARGOCD_SERVER=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[].ip}')
      sleep 5
  done

  echo -e "Argocd server is running at the public address: ${ARGOCD_SERVER}"
  echo -e "Waiting for argocd server API to become responsive"
  while [ -z "${ARGOCD_HEALTH}" ]; do
      ARGOCD_HEALTH=$(curl -k https://${ARGOCD_SERVER}/api/version | jq '.Version' -r)
      sleep 5
  done
  echo -e "Finished installing argocd to the cluster, boostraping cluster"

  #
  # log into argocd, if the CLI is not found then install it
  #
  if [ ! -f $HOME/.local/bin/argocd ];
  then
      wget -O argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
      chmod +x argocd
      mv argocd $HOME/.local/bin
  fi

  #
  # update the TLS cert that argocd uses to match the actual domain name
  #
  kubectl patch secrets -n argocd argocd-secret \
  -p="{\"data\":{\"tls.crt\": \"${TLS_CERT}\", \"tls.key\":\"${TLS_KEY}\"}}"

  #
  # argocd CLI login
  # the Here Document 'y' is to answer the interactive prompt with "yes"
  argocd login ${ARGOCD_SERVER} \
      --username admin \
      --password ${ARGOCD_PASSWORD} <<EOF
y
EOF

  argocd repo add ${GITOPS_REPO_URL}

  #
  # bootstrap the cluster with applications from the GitOps repo
  # we use the Application of applications approach described in argocd's documentations here: 
  # https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/
  #
  argocd app create applications \
      --dest-namespace argocd \
      --dest-server https://kubernetes.default.svc \
      --repo ${GITOPS_REPO_URL} \
      --path applications \
      --sync-policy automated
}

#
# install tools
#
install_tools() {
    mkdir -p ~/.kube

    echo -e "Installing kubectl"
    sudo curl \
        --silent \
        --location \
        -o /usr/local/bin/kubectl \
        https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/kubectl
    sudo chmod +x /usr/local/bin/kubectl

    echo -e "Installing aws-iam-authenticator"
    sudo curl \
        --silent \
        --location \
        -o aws-iam-authenticator \
        https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
    sudo chmod +x aws-iam-authenticator
    sudo mv aws-iam-authenticator /usr/local/bin/aws-iam-authenticator

    echo -e "Installing jq, gettext"
    sudo yum -y install jq gettext

    echo -e "Installing eksctl"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv -v /tmp/eksctl /usr/local/bin

    #
    # verify the binaries are in the path and executable
    #
    for command in kubectl eksctl aws-iam-authenticator jq envsubst
    do
        which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
    done
}

validate_iam_role() {
    #
    # check the script is running using the proper IAM role
    # 
    local ROLE_ARN=$(aws sts get-caller-identity --query Arn --output text)
    TXT=$(echo ${ROLE_ARN} | sed -ne '/^arn:aws:sts::[0-9]*:assumed-role\/AmazonEKSProvisionerRole\/[a-z0-9]*/p' )
    if [[ -z $TXT ]] 
    then
        echo -e "Invalid IAM role found"
        exit 1
    else
        echo -e "IAM role ${ROLE_ARN} validated"
    fi
}

validate_iam_role
install_tools

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

eksctl create cluster \
  --name=eksworkshop-eksctl \
  --nodes=3 \
  --node-ami=auto \
  --region=${AWS_REGION}
