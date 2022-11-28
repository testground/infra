#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

NAME=$1

if [ -z "$NAME" ]
then
  echo -e "Please provider a NAME as argument. For example: \`./make-image-public.sh testground_2020-06-09\`"
  exit 2
fi


regions=("eu-central-1" "eu-west-1" "eu-west-2" "us-west-1" "us-west-2" "us-east-1" "us-east-2" "ap-southeast-1")

for i in ${!regions[@]};
do
  region=${regions[$i]}

  ami_id=`aws ec2 describe-images --owners 909427826938 --region=$region --filters="Name=name,Values=$NAME" --output text | awk '{print $6}' | head -1`

  echo "Making $ami_id in region $region public"

  aws ec2 modify-image-attribute \
      --image-id $ami_id \
      --region $region \
      --launch-permission "Add=[{Group=all}]"
done
