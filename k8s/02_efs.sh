#!/bin/bash

set -o errexit
set -o pipefail
set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

START_TIME=`date +%s`

CLUSTER_SPEC_TEMPLATE=$1

my_dir="$(dirname "$0")"
source "$my_dir/install-playbook/validation.sh"

echo "Installing EFS..."

vpcId=`aws ec2 describe-vpcs --region=$AWS_REGION --filters Name=tag:Name,Values=$CLUSTER_NAME --output text | awk '/VPCS/ { print $8 }'`

if [[ -z ${vpcId} ]]; then
  echo "Couldn't detect AWS VPC created by `kops`"
  exit 1
fi

echo "Detected VPC: $vpcId"

securityGroupId=`aws ec2 describe-security-groups --region=$AWS_REGION --output text | awk '/nodes.'$CLUSTER_NAME'/ && /SECURITYGROUPS/ { print $6 };'`

if [[ -z ${securityGroupId} ]]; then
  echo "Couldn't detect AWS Security Group created by `kops`"
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

# create EFS file system
terraform init -backend-config=bucket=$S3_BUCKET \
               -backend-config=key=${DEPLOYMENT_NAME}-efs \
               -backend-config=region=$AWS_REGION

terraform apply -var aws_region=$AWS_REGION -var fs_subnet_id_zone_a=$subnetIdZoneA -var fs_subnet_id_zone_b=$subnetIdZoneB -var fs_sg_id=$securityGroupId -auto-approve

export EFS_DNSNAME=`terraform output dns_name`

fsId=`terraform output filesystem_id`

popd

echo "Install EFS Kubernetes provisioner..."

kubectl create configmap efs-provisioner \
--from-literal=file.system.id=$fsId \
--from-literal=aws.region=$AWS_REGION \
--from-literal=provisioner.name=testground.io/aws-efs

EFS_MANIFEST_SPEC=$(mktemp)
envsubst <./efs/manifest.yaml.spec >$EFS_MANIFEST_SPEC

kubectl apply -f ./efs/rbac.yaml \
              -f $EFS_MANIFEST_SPEC

echo "Wait for EFS provisioner to be Running..."
echo
RUNNING_EFS=0
while [ "$RUNNING_EFS" -ne 1 ]; do RUNNING_EFS=$(kubectl get pods | grep efs-provisioner | grep Running | wc -l || true); echo "Got $RUNNING_EFS running efs-provisioner pods"; sleep 5; done;

echo "EFS provisioner is ready"
echo

END_TIME=`date +%s`
echo "Execution time was `expr $END_TIME - $START_TIME` seconds"
