./validate_iam_role.sh
./install_tools.sh

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

eksctl create cluster \
  --name=eksworkshop-eksctl \
  --nodes=3 \
  --node-ami=auto \
  --region=${AWS_REGION}

./initialize-secrets.sh
./install-argocd.sh
./configure-route53.sh