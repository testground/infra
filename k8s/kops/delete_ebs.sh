#!/bin/bash

set -o errexit
set -o pipefail
set -x
set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

pushd ebs-terraform

# extract s3 bucket from kops state store
S3_BUCKET="${KOPS_STATE_STORE:5:100}"

terraform init -backend-config=bucket=$S3_BUCKET \
               -backend-config=key=${DEPLOYMENT_NAME}-ebs \
               -backend-config=region=$AWS_REGION

terraform destroy -var aws_region=$AWS_REGION -var aws_availability_zone=${AWS_REGION}a -auto-approve

popd
