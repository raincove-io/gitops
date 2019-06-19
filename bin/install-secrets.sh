#!/bin/bash

SEALED_SECRET_VERSION=v0.7.0

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
# install the TLS certificates as a tls secret in the cluster
#
echo ${TLS_KEY} | base64 -d > key.pem
echo ${TLS_CERT} | base64 -d > cert.pem
CERT_NAME=nginx-tls
kubectl create secret tls ${CERT_NAME} --key key.pem --cert cert.pem
rm key.pem cert.pem

#
# install SealedSecret CRD, server-side controller into kube-system namespace (by default)
# Note the second sealedsecret-crd.yaml file is not necessary for releases >= 0.8.0
#
echo -e "installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster ..."
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/controller.yaml
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/sealedsecret-crd.yaml

echo -e "finished installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster"