#!/bin/bash

# =======================================================
# Description:
# This script is used to spin up a new Kubernetes cluster using Kops.
# Also, the tool creates an ArgoCD app to provision the cluster.
#
# The following variables are required to make it work
# CLUSTER_NAME=
# DEPLOYMENT_NAME=
# WORKER_NODE_TYPE=
# MASTER_NODE_TYPE=
# MIN_WORKER_NODES=
# MAX_WORKER_NODES=
# TEAM=
# PROJECT=
# AWS_REGION=
# KOPS_STATE_STORE=
# ZONE_A=
# ZONE_B=
# PUBKEY=
# AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
# AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
# =======================================================

set -o errexit
set -o pipefail
set -e

# =======================================================
TF_RESOURCES="../../terraform/kops-resources/"
ARGOCD_VERSION="5.31.0"
# =======================================================
err_report() {
    echo "Error on line $1"
}
# =======================================================
trap 'err_report $LINENO' ERR
# =======================================================
START_TIME=`date +%s`
# =======================================================

# Load values form the file
if [ -f ./values.sh ];then
    source ./values.sh
else
    echo "[ERROR] Please, you need to fill the values in the script [values.sh]"
    exit 1
fi

# =======================================================
echo "Creating cluster for Testground..."
echo
CLUSTER_SPEC_TEMPLATE=$1

my_dir="$(dirname "$0")"
source "$my_dir/install-playbook/validation.sh"

echo "Required arguments"
echo "------------------"
echo "Deployment name (DEPLOYMENT_NAME): $DEPLOYMENT_NAME"
echo "Cluster name (CLUSTER_NAME): $CLUSTER_NAME"
echo "Kops state store (KOPS_STATE_STORE): $KOPS_STATE_STORE"
echo "AWS availability zone A (ZONE_A): $ZONE_A"
echo "AWS availability zone B (ZONE_B): $ZONE_B"
echo "AWS region (AWS_REGION): $AWS_REGION"
echo "AWS worker node type (WORKER_NODE_TYPE): $WORKER_NODE_TYPE"
echo "AWS master node type (MASTER_NODE_TYPE): $MASTER_NODE_TYPE"
echo "Min number of Worker nodes (MIN_WORKER_NODES): $MIN_WORKER_NODES"
echo "Max number of Worker nodes (MAX_WORKER_NODES): $MAX_WORKER_NODES"
echo "Public key (PUBKEY): $PUBKEY"
echo

CLUSTER_SPEC=$(mktemp)
envsubst <$CLUSTER_SPEC_TEMPLATE >$CLUSTER_SPEC

# =======================================================
# Verify with the user before continuing.
echo
echo "The cluster will be built based on the params above."
echo -n "Do they look right to you? [y/n]: "
read response
if [ "$response" != "y" ]
then
  echo "Canceling ."
  exit 2
fi

# =======================================================
# The remainder of this script creates the cluster using the generated template
kops create -f $CLUSTER_SPEC
kops create secret --name $CLUSTER_NAME sshpublickey admin -i $PUBKEY
# The following command updates the cluster and updates the kubeconfig
kops update cluster $CLUSTER_NAME --admin --yes
# Wait for worker nodes and master to be ready
kops validate cluster --wait 20m
echo "Cluster nodes are Ready"
echo

# =======================================================
echo "Create EFS resources & storageclasses..."
cd ${TF_RESOURCES}
# we used the && to be sure that the previous command was executed properly
terraform init &&\
terraform plan &&\
terraform apply -auto-approve &&\
cd -
pwd

# =======================================================
echo "Installing ArgoCD"
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
     --version ${ARGOCD_VERSION} \
     --namespace=argocd \
     -f ./argocd/values.yaml

echo "Giving some seconds to ArgoCD to be operative..."
sleep 20

# =======================================================
echo "Installing root app..."
kubectl apply -f - <<EOF
# We generate this ArgoCD application with Terraform, but we keep it here as a workaround
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/testground/infra.git
    path: 'argocd'
    targetRevision: v0.7.0
  destination:
    name: in-cluster
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      allowEmpty: true
      selfHeal: true
    syncOptions:
    - ApplyOutOfSyncOnly=true
    - CreateNamespace=true
EOF

# =======================================================
END_TIME=`date +%s`
echo "Execution time was `expr $END_TIME - $START_TIME` seconds"
# =======================================================
