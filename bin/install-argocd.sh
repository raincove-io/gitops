#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

source ${DIR}/init-env.sh

ARGOCD_VERSION=v1.0.2
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

echo -e "Finished installing argocd to the cluster"

#
# log into argocd, if the CLI is not found then install it
#
if [[ ! -f /usr/local/bin/argocd ]];
then
    wget -O argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
    chmod +x argocd
    sudo mv argocd /usr/local/bin
    echo "Finished install argocd CLI at $(which argocd)"
fi

#
# update the TLS cert that argocd uses to match the actual domain name
#
kubectl patch secrets -n argocd argocd-secret \
-p="{\"data\":{\"tls.crt\": \"${TLS_CERT}\", \"tls.key\":\"${TLS_KEY}\"}}"
