#!/bin/bash

while getopts ":u:e:" opt; do
  case ${opt} in
    e)
      ENVIRONMENT=$OPTARG
    \?) echo "Usage: -u <gitops url>"
      ;;
  esac
done

if [[ -z ${ENVIRONMENT} ]];
then
    echo "-e <environment> is not specified"
    exit 1
fi

#
# we assume route 53 have a DNS CNAME record for argocd
#
ARGOCD_SERVER=argocd-${ENVIRONMENT}.raincove.io
HEALTH_CHECK_URL=https://${ARGOCD_SERVER}/api/version
echo -e "Waiting for argocd server API to become responsive at ${HEALTH_CHECK_URL}"
while [ -z "${ARGOCD_HEALTH}" ]; do
    ARGOCD_HEALTH=$(curl -k ${HEALTH_CHECK_URL} | jq '.Version' -r)
    sleep 5
done
GITOPS_REPO_URL=https://github.com/raincove-io/gitops.git
echo -e "Logging into the CLI, creating the application of applications at ${GITOPS_REPO_URL}"

#
# argocd CLI login
# the Here Document 'y' is to answer the interactive prompt with "yes"
#
ARGOCD_PASSWORD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
argocd login ${ARGOCD_SERVER} \
    --username admin \
    --password ${ARGOCD_PASSWORD}

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
    --sync-policy automated \
    -p environment=${ENVIRONMENT}
