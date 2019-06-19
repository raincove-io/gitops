#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

source $DIR/init-env.sh
init_env

#
# read CLI command options
#
while getopts ":e:" opt; do
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
# host running the bootstrap process. This initial EKS cluster uses a default nodegroup of a modest size, using t3.small instance worker nodes
# subsequent upgrades and nodegroup configurations can be changed via the AWS ASG APIs
#
eksctl create cluster \
  --name=${ENVIRONMENT}-raincove-io \
  --nodes=3 \
  --node-ami=auto \
  --node-type=t3.small \
  --zones=${AWS_REGION}a,${AWS_REGION}b,${AWS_REGION}c \
  --region=${AWS_REGION}

#
# install TLS certificates into the cluster, these certificates and key have been pre-generated
# as well as sealed-secrets
#
${DIR}/install-secrets.sh

#
# install argocd so we can begin to run gitops, this is broken into 3 steps
# 1 - install argocd into the k8s cluster, create a LoadBalancer
# 2 - create a CNAME record from a friendly hostname to the LoadBalancer in route 53
# 3 - configure argocd to install applications stored in GitOps (including ingress controller)
#
${DIR}/install-argocd.sh
${DIR}/configure-route53-argocd.sh -e ${ENVIRONMENT}
${DIR}/init-argocd.sh -e ${ENVIRONMENT}

#
# at this point, all of our applications are installed on the cluster including the ingress controller
# the final step is to give the ingress controller a CNAME record in route 53
#
${DIR}/configure-route53.sh -e ${ENVIRONMENT}