#!/bin/bash

echo "Initializing environment variables"

#
# always install EKS cluster in the region we are currently runnning in to prevent ambiguities
#
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

#
# extract TLS certificates from secrets manager as environment variables
#
export TLS_KEY=$(aws secretsmanager get-secret-value --region ${AWS_REGION} \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.key')
export TLS_CERT=$(aws secretsmanager get-secret-value --region ${AWS_REGION} \
--secret-id raincove/io/tls-cert| jq --raw-output '.SecretString' | jq -r '.cert')

echo "ACCOUNT_ID=${ACCOUNT_ID}"
echo "AWS_REGION=${AWS_REGION}"