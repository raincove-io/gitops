#!/bin/bash

while getopts ":u:" opt; do
  case ${opt} in
    u)
      GITOPS_REPO_URL=$OPTARG
      ;;
    \?) echo "Usage: -u <gitops url>"
      ;;
  esac
done

if [[ -z ${GITOPS_REPO_URL} ]]
then
    echo "-u <gitops url> not specified"
    exit 1
fi

if [[ -z ${TLS_CERT} ]]
then
    echo "TLS_CERT not defined, please run initialize-secrets.sh"
    exit 1
fi

if [[ -z ${TLS_KEY} ]]
then
    echo "TLS_KEY not defined, please run initialize-secrets.sh"
    exit 1
fi

ARGOCD_VERSION=v0.12.3
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
if [[ ! -f $HOME/.local/bin/argocd ]];
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

export ARGOCD_SERVER=${ARGOCD_SERVER}