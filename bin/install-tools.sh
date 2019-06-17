mkdir -p ~/.kube

echo -e "Installing kubectl"
sudo curl \
    --silent \
    --location \
    -o /usr/local/bin/kubectl \
    https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl

echo -e "Installing aws-iam-authenticator"
sudo curl \
    --silent \
    --location \
    -o aws-iam-authenticator \
    https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
sudo chmod +x aws-iam-authenticator
sudo mv aws-iam-authenticator /usr/local/bin/aws-iam-authenticator

echo -e "Installing jq, gettext"
sudo yum -y install jq gettext

echo -e "Installing eksctl"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin

#
# verify the binaries are in the path and executable
#
for command in kubectl eksctl aws-iam-authenticator jq envsubst
do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
done