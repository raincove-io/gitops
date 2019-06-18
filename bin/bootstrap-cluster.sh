#!/usr/bin/env bash

while getopts ":u:e:a" opt; do
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
./validate_iam_role.sh
./install_tools.sh

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

#
# run the EKS bootstrap
#
eksctl create cluster \
  --name=eksworkshop-eksctl \
  --nodes=3 \
  --node-ami=auto \
  --region=${AWS_REGION}

#
# initialize TLS certificate as environment variables, k8s secrets
#
./initialize-secrets.sh

#
# install argocd so we can begin to run gitops
#
./install-argocd.sh -u ${GITOPS_REPO_URL}

if [[ -z ${ARGOCD_SERVER} ]]
then
    echo "cannot find environment variable ARGOCD_SERVER, please run install-argocd.sh"
    exit 1
fi

#
# configure DNS records to the new cluster
#
./configure-route53.sh -e ${ENVIRONMENT} -a ${ARGOCD_SERVER}