#!/bin/sh

securityGroupId=`aws ec2 describe-security-groups --region=$AWS_REGION --output text | awk '/nodes.'$NAME'/ && /SECURITYGROUPS/ { print $6 };'`

if [[ -z ${securityGroupId} ]]; then
  echo "Couldn't detect AWS Security Group created by `kops`"
  exit 1
fi

aws ec2 authorize-security-group-ingress \
    --group-id $securityGroupId \
    --ip-permissions IpProtocol=tcp,FromPort=19999,ToPort=19999,IpRanges='[{CidrIp=0.0.0.0/0}]'
