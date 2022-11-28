#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

NAME=$1
SOURCE_IMAGE_ID=$2

if [ -z "$NAME" ]
then
  echo -e "Please provider a NAME and SOURCE_IMAGE_ID as arguments. For example: \`./distribute-image.sh testground_2020-06-09 ami-05f1bda5da619ca5b\`"
  exit 2
fi

if [ -z "$SOURCE_IMAGE_ID" ]
then
  echo -e "Please provider a NAME and SOURCE_IMAGE_ID as arguments. For example: \`./distribute-image.sh testground_2020-06-09 ami-05f1bda5da619ca5b\`"
  exit 2
fi

aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region eu-west-1
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region eu-central-1
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region us-east-1
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region us-east-2
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region us-west-1
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region us-west-2
aws ec2 copy-image --name $NAME --source-image-id $SOURCE_IMAGE_ID  --source-region eu-west-2 --region ap-southeast-1
