#!/bin/bash

#set -x

cd admin
echo $(aws sts get-caller-identity) #alternately,
#echo "`aws sts get-caller-identity`"
sleep 5

terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file="secrets.tfvars"
terraform apply -var-file="secrets.tfvars" -auto-approve
###########################################################

cd ../resources
TF_VAR_environment=prod
ENVIRONMENT="${TF_VAR_environment}"
TF_PLAN="${ENVIRONMENT}.tfplan"
TF_PLAN_JSON="${TF_PLAN}.json"
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_AWS_ROLE=ec2-admin-role
export VAULT_TOKEN=(cat ~/.vault-token)
sleep 5

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
sleep 5

export AWS_CREDS="$(vault read aws/creds/${VAULT_AWS_ROLE} -format=json)"
export AWS_ACCESS_KEY_ID="$(echo $AWS_CREDS | jq -r .data.access_key)"
export AWS_SECRET_ACCESS_KEY="$(echo $AWS_CREDS | jq -r .data.secret_key)"
export AWS_DEFAULT_REGION="us-west-2"

[ -d .terraform ] && rm -rf .terraform # alternatively, 

: << 'END_COMMENT'
if
    [ -d .terraform ];
then
    rm -rf .terraform;
else
    echo "directory not found"
fi
END_COMMENT

if [ -z "${AWS_SECRET_ACCESS_KEY}" ] || [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_DEFAULT_REGION}" ] || [ -z "${ENVIRONMENT}" ];
then
    echo "AWS credentials and default region must be set!"
    exit 1
fi
sleep 10
terraform fmt -recursive -diff -check
terraform init
terraform validate
echo $(aws sts get-caller-identity)
terraform plan -var-file="secrets.tfvars" -out=${TF_PLAN} 
terraform show -json ${TF_PLAN} >${TF_PLAN_JSON}
checkov -f ${TF_PLAN_JSON}
sleep 5

if [ ! -f "${TF_PLAN}" ]; then
    echo "****** Plan from previous job does not exist. Exiting! ******"
    exit 1
fi
#terraform apply ${TF_PLAN}
#rm -f *.tfplan*
#terraform destroy -auto-approve


