#!/usr/bin/env bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

#
# read CLI command options
#
while getopts ":u:e:" opt; do
  case ${opt} in
    u)
      GITOPS_REPO_URL=$OPTARG
      ;;
    e)
      ENVIRONMENT=$OPTARG
      ;;
  esac
done

if [[ -z ${GITOPS_REPO_URL} ]]
then
    echo "-u <gitops url> not specified"
    exit 1
fi

if [[ -z ${ENVIRONMENT} ]]
then
    echo "-e <environment> not specified"
    exit 1
fi

#
# install tools and prepare
#
${DIR}/validate-env.sh
${DIR}/install-tools.sh

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
#
# always install EKS cluster in the region we are currently runnning in to prevent ambiguities
#
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

#
# run the EKS bootstrap via eksctl, this creates 2 stacks: nodegroup and control plane stacks and writes kubeconfig into the 
# host running the bootstrap process
#
eksctl create cluster \
  --name=${ENVIRONMENT}-raincove-io \
  --nodes=3 \
  --node-ami=auto \
  --region=${AWS_REGION}

#
# initialize TLS certificate as environment variables, k8s secrets
#
${DIR}/initialize-secrets.sh

#
# assert that TLS_CERT and TLS_KEY are now populated
# these are going to attached to argocd's HTTPS server and the ingress controller server
#
if [[ -z ${TLS_CERT} ]];
then
  echo "TLS_CERT environment was not properly initialized"
  exit 1
fi

if [[ -z ${TLS_KEY} ]];
then
  echo "TLS_KEY environment was not properly initialized"
  exit 1
fi

#
# install argocd so we can begin to run gitops
#
${DIR}/install-argocd.sh -u ${GITOPS_REPO_URL}

if [[ -z ${ARGOCD_SERVER} ]]
then
    echo "cannot find environment variable ARGOCD_SERVER, please run install-argocd.sh"
    exit 1
fi

#
# configure DNS records to the new cluster
#
${DIR}/configure-route53.sh -e ${ENVIRONMENT} -a ${ARGOCD_SERVER}