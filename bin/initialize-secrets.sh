#!/usr/bin/env bash
SEALED_SECRET_VERSION=v0.7.0

#
# install TLS certificate
#
export TLS_KEY=$(aws secretsmanager get-secret-value \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.key')
echo ${TLS_KEY} | base64 -d > key.pem

export TLS_CERT=$(aws secretsmanager get-secret-value \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.cert')
echo ${TLS_CERT} | base64 -d > cert.pem

CERT_NAME=nginx-tls
kubectl create secret tls ${CERT_NAME} --key key.pem --cert cert.pem

#
# clean up the certificates from the local FS
#
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