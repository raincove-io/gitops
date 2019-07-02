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
echo -e "Installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster ..."
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/controller.yaml
kubectl apply \
    -f https://github.com/bitnami-labs/sealed-secrets/releases/download/${SEALED_SECRET_VERSION}/sealedsecret-crd.yaml

#
# install the sealed-secret master key, which is used to
# encrypt all other secrets on the cluster (exL OAuth clientSecret, api keys, database passwords etc.)
# thus it is required to bootstrap the cluster
#
MASTER_CRT=$(aws secretsmanager get-secret-value --region ${AWS_REGION} --secret-id raincove/io/sealed-secrets-crt --query SecretString --output text)
MASTER_KEY=$(aws secretsmanager get-secret-value --region ${AWS_REGION} --secret-id raincove/io/sealed-secrets-key --query SecretString --output text)

sleep 10;
if [[ -z "${MASTER_KEY}" || -z "${MASTER_CRT}" ]]
then
  echo "Cannot find a master key from secretsmanager, using the generated key instead, if the GitOps repository have encrypted secrets, they must all be re-encrypted!!"
  MASTER_CRT=$(kubectl -n kube-system get secret sealed-secrets-key -o jsonpath='{.data.tls\.crt}')
  MASTER_KEY=$(kubectl -n kube-system get secret sealed-secrets-key -o jsonpath='{.data.tls\.key}')
  echo "Backing up the generated master key into secretsmanager"
  
  aws secretsmanager create-secret \
    --name raincove/io/sealed-secrets-crt \
    --region ${AWS_REGION} \
    --secret-string "${MASTER_CRT}"
    
  aws secretsmanager create-secret \
    --name raincove/io/sealed-secrets-key \
    --region ${AWS_REGION} \
    --secret-string "${MASTER_KEY}"
    
else
  echo "Found master key in secrets manager, replacing the generated key"
  cat <<EOF | kubectl -n kube-system replace -f -
apiVersion: v1
data:
  tls.crt: ${MASTER_CRT}
  tls.key: ${MASTER_KEY}
kind: Secret
metadata:
  creationTimestamp: null
  namespace: kube-system
  name: sealed-secrets-key
  selfLink: /api/v1/namespaces/kube-system/secrets/sealed-secrets-key
type: kubernetes.io/tls
EOF
  echo "Deleting pods of sealed-secrets-controller, k8s will restart them to pick up the new master key"
  kubectl delete -n kube-system pod -l name=sealed-secrets-controller
fi

echo -e "Finished installing SealedSecret ${SEALED_SECRET_VERSION} to the cluster"