#!/bin/bash

while getopts ":e:" opt; do
  case ${opt} in
    e)
      ENVIRONMENT=$OPTARG
      ;;
  esac
done

if [[ -z ${ENVIRONMENT} ]]
then
    echo "-e <environment> not specified"
    exit 1
fi

#
# we look for a service with a LoadBalancer type that is our ingress nginx
#
echo "Waiting for a hostname to appear for the service ingress-nginx"
while [ -z "$NGINX_LB_ADDRESS" ]; do
    NGINX_LB_ADDRESS=$(kubectl -n ingress-nginx get svc ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[].hostname}')
    sleep 5
done
echo "Service ingress-nginx have ELB address ${NGINX_LB_ADDRESS}"


#
# create a ResourceRecordSet in the hosted zone in route 53 to point to argocd / default nginx-ingress
#
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == 'raincove.io.'].Id" --output text)
echo -e "hosted-zone-id resolved to ${HOSTED_ZONE_ID}"
cat <<EOF > route53-request.json
  {
    "Comment": "CREATE/DELETE/UPSERT a record ",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "${ENVIRONMENT}.raincove.io",
          "Type": "CNAME",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${NGINX_LB_ADDRESS}"
            }
          ]
        }
      }    
    ]
  }
EOF
echo -e "Adding CNAME records for hosted-zone-id=${HOSTED_ZONE_ID} ..."
aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file://route53-request.json

rm route53-request.json