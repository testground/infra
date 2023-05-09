#!/bin/bash

# Description:
# This script is used to spin up a new Kubernetes cluster using Kops.
# Also, the tool creates an ArgoCD app to provision the cluster.
#
# The following variables are required to make it work
# CLUSTER_NAME=
# DEPLOYMENT_NAME=
# WORKER_NODE_TYPE=
# MASTER_NODE_TYPE=
# WORKER_NODES=
# TEAM=
# PROJECT=
# AWS_REGION=
# KOPS_STATE_STORE=
# ZONE_A=
# ZONE_B=
# PUBKEY=
# AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
# AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

set -o errexit
set -o pipefail
set -e

TF_RESOURCES="../../terraform/kops-resources/"

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

START_TIME=`date +%s`

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
echo "Worker nodes (WORKER_NODES): $WORKER_NODES"
echo "Public key (PUBKEY): $PUBKEY"
echo

CLUSTER_SPEC=$(mktemp)
envsubst <$CLUSTER_SPEC_TEMPLATE >$CLUSTER_SPEC

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

echo "Install default container limits"
echo
# kubectl apply -f ./limit-range/limit-range.yaml

echo "Install Weave, CNI-Genie, Sidecar Daemonset..."
echo

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml
# -f ./sidecar.yaml
#./kops-weave/weave.yml \
# -f ./kops-weave/genie-plugin.yaml \
# -f ./kops-weave/dummy.yml \

echo "Installing ArgoCD"
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
     --version 5.31.0 \
     --namespace=argocd \
     -f ./argocd/values.yaml

echo "Giving some seconds to ArgoCD to be operative..."
sleep 20

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
    repoURL: https://github.com/celestiaorg/testground-infra.git
    path: 'argocd'
    targetRevision: jose/hackground-k8s-tf
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

#echo "Install Weave service monitor..."
#echo
#
#kubectl apply -f ./kops-weave/weave-metrics-service.yml \
#              -f ./kops-weave/weave-service-monitor.yml

# echo "Wait for Sidecar to be Ready..."
# echo
# RUNNING_SIDECARS=0
# while [ "$RUNNING_SIDECARS" -ne "$WORKER_NODES" ]; do RUNNING_SIDECARS=$(kubectl get pods | grep testground-sidecar | grep Running | wc -l || true); echo "Got $RUNNING_SIDECARS running sidecar pods"; sleep 5; done;#

# echo "Testground cluster is installed"
# echo

END_TIME=`date +%s`
echo "Execution time was `expr $END_TIME - $START_TIME` seconds"