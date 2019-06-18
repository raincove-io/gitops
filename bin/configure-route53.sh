#!/bin/bash

while getopts ":e:a" opt; do
  case ${opt} in
    e)
      ENVIRONMENT=$OPTARG
      ;;
    a)
      ARGOCD_SERVER=$OPTARG
      ;;
  esac
done

if [[ -z ${ENVIRONMENT} ]]
then
    echo "-e <environment> not specified"
    exit 1
fi

if [[ -z ${ARGOCD_SERVER} ]]
then
    echo "-a <argocd server ip> not specified"
fi

#
# create a ResourceRecordSet in the hosted zone in route 53 to point to argocd / default nginx-ingress
#
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == 'raincove.io.'].Id" --output text)
echo -e "hosted-zone-id resolved to ${HOSTED_ZONE_ID}"
NGINX_PUBLIC_IP=$(kubectl get svc -n ingress-nginx -o jsonpath='{.items[].status.loadBalancer.ingress[].ip}')
cat <<EOF > route53-request.json
  {
    "Comment": "CREATE/DELETE/UPSERT a record ",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "${ENVIRONMENT}.raincove.io",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${NGINX_PUBLIC_IP}"
            }
          ]
        }
      },
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "argocd-${ENVIRONMENT}.raincove.io",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${ARGOCD_SERVER}"
            }
          ]
        }
      }    
    ]
  }
EOF
echo -e "Adding A records for hosted-zone-id=${HOSTED_ZONE_ID} ..."
aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file://route53-request.json

rm route53-request.json