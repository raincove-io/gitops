#!/usr/bin/env bash
SEALED_SECRET_VERSION=v0.7.0

#
# install TLS certificate
#
export TLS_KEY=$(aws secretsmanager get-secret-value --region ${AWS_REGION} \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.key')
echo ${TLS_KEY} | base64 -d > key.pem

export TLS_CERT=$(aws secretsmanager get-secret-value --region ${AWS_REGION} \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.cert')
echo ${TLS_CERT} | base64 -d > cert.pem

#
# the ingress controller (configured via the GitOps repository - will be looking for this secret as a fallback TLS certificate to use)
# we do not use ELB / classic ELB TLS termination with certificate provisioned through ACM
#
CERT_NAME=nginx-tls
kubectl create secret tls ${CERT_NAME} --key key.pem --cert cert.pem

#
# clean up the certificates from the local FS so they are not leaked
#
rm key.pem cert.pem

#
# install SealedSecret CRD, server-side controller into kube-system namespace (by default)
# Note the second sealedsecret-crd.yaml file is not necessary for releases >= 0.8.0
#
# TODO this should be its own script - where we retrieve the master RSA keys from aws secrets manager if one exists and generate one
# if one does not exist
# 
echo -e "Installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster ..."
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/controller.yaml
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/sealedsecret-crd.yaml

echo -e "Finished installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster"