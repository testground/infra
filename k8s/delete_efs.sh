#!/bin/bash

set -o errexit
set -o pipefail
set -x
set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=$CLUSTER_NAME --output text | awk '/VPCS/ { print $8 }'`

if [[ -z ${vpcId} ]]; then
  echo "Couldn't detect AWS VPC created by kops"
  exit 1
fi

echo "Detected VPC: $vpcId"

securityGroupId=`aws ec2 describe-security-groups --output text | awk '/nodes.'$CLUSTER_NAME'/ && /SECURITYGROUPS/ { print $6 };'`

if [[ -z ${securityGroupId} ]]; then
  echo "Couldn't detect AWS Security Group created by kops"
  exit 1
fi

echo "Detected Security Group ID: $securityGroupId"

subnetIdZoneA=`aws ec2 describe-subnets --region=$AWS_REGION --output text | awk '/'$vpcId'/ { print $13 }' | sort | head -1`
subnetIdZoneB=`aws ec2 describe-subnets --region=$AWS_REGION --output text | awk '/'$vpcId'/ { print $13 }' | sort | tail -1`

echo "Detected Subnet: $subnetIdZoneA"
echo "Detected Subnet: $subnetIdZoneB"

pushd efs-terraform

# extract s3 bucket from kops state store
S3_BUCKET="${KOPS_STATE_STORE:5:100}"

terraform init -backend-config=bucket=$S3_BUCKET \
               -backend-config=key=${DEPLOYMENT_NAME}-efs \
               -backend-config=region=$AWS_REGION

terraform destroy -var aws_region=$AWS_REGION -var fs_subnet_id_zone_a=$subnetIdZoneA -var fs_subnet_id_zone_b=$subnetIdZoneB -var fs_sg_id=$securityGroupId -auto-approve

popd
