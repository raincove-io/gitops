#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

$DIR/init-env.sh

#
# read CLI command options
#
while getopts ":u:e:" opt; do
  case ${opt} in
    e)
      ENVIRONMENT=$OPTARG
      ;;
  esac
done

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

#
# run the EKS bootstrap via eksctl, this creates 2 stacks: nodegroup and control plane stacks and writes kubeconfig into the 
# host running the bootstrap process. This initial EKS cluster uses a default nodegroup of a modest size, using m5.large instance worker nodes
# subsequent upgrades and nodegroup configurations can be changed via the AWS ASG APIs
#
eksctl create cluster \
  --name=${ENVIRONMENT}-raincove-io \
  --nodes=3 \
  --node-ami=auto \
  --zones=${AWS_REGION}a,${AWS_REGION}b,${AWS_REGION}c \
  --region=${AWS_REGION}

#
# install TLS certificates into the cluster, these certificates and key have been pre-generated
#
${DIR}/install-secrets.sh

#
# install argocd so we can begin to run gitops
#
${DIR}/install-argocd.sh

#
# configure DNS records to the new cluster
#
${DIR}/configure-route53.sh -e ${ENVIRONMENT}

#
# after the routes for argocd has been configured TLS handshakes should succeed at the public domain name argocd-<environment>.raincove.io
#
${DIR}/init-argocd.sh -e ${ENVIRONMENT}