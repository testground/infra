#!/bin/bash
# =======================================================
# Description:
# This script is used to load the values.
# =======================================================

export CLUSTER_NAME=
export DEPLOYMENT_NAME=
export WORKER_NODE_TYPE=
export MASTER_NODE_TYPE=
export MIN_WORKER_NODES=
export MAX_WORKER_NODES=
export TEAM=
export PROJECT=
export AWS_REGION=
export KOPS_STATE_STORE=s3://
export ZONE_A=
export ZONE_B=
export PUBKEY=
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

# Node types -> https://aws.amazon.com/es/ec2/instance-types/
# c5.2xlarge # 8CPU/16RAM
# c5.4xlarge # 16CPU/32RAM
# c5.9xlarge # 36CPU/72RAM
# c5a.24xlarge # 96CPU/192RAM
