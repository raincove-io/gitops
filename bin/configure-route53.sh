
ENVIRONMENT=$1
ARGOCD_SERVER=$2

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