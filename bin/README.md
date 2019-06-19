# k8s Cluster Scripts

These scripts are used to provision new Kuberentes clusters on brand new AWS accounts. They can be run In order. The master script that invokes the helper script is `bootstrap-cluster.sh`

## Steps Performed

- Initialize environment variables (AWS_REGION / ACCOUNT_ID / TLS_CERT / TLS_KEY)

- Validate the current IAM role

- Install all the necessary tools such as kubectl / eksctl

- Launch EKS cluster

- Install the TLS certificates as secrets

- Install and Configure argocd

- Configure DNS CNAME records through Route53
