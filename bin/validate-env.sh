#
# check the script is running using the proper IAM role
# 
ROLE_ARN=$(aws sts get-caller-identity --query Arn --output text)
TXT=$(echo ${ROLE_ARN} | sed -ne '/^arn:aws:sts::[0-9]*:assumed-role\/AmazonEKSProvisionerRole\/[a-z0-9]*/p' )
if [[ -z $TXT ]] 
then
    echo -e "Invalid IAM role found"
    exit 1
else
    echo -e "IAM role ${ROLE_ARN} validated"
fi