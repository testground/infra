#!/bin/bash

set -o errexit
set -o pipefail
set -e

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
kops update cluster $CLUSTER_NAME --admin --yes

# Wait for worker nodes and master to be ready
kops validate cluster --wait 20m

echo "Cluster nodes are Ready"
echo

echo "Install default container limits"
echo

kubectl apply -f ./limit-range/limit-range.yaml

echo "Install Weave, CNI-Genie, Sidecar Daemonset..."
echo

kubectl apply -f ./kops-weave/weave.yml \
              -f ./kops-weave/genie-plugin.yaml \
              -f ./kops-weave/dummy.yml \
              -f ./sidecar.yaml

echo "Installing ArgoCD"
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --version 5.31.0 \
  --namespace=argocd \
  --set redis-ha.enabled=true \
  --set controller.replicas=1 \
  --set server.autoscaling.enabled=true \
  --set server.autoscaling.minReplicas=2 \
  --set repoServer.autoscaling.enabled=true \
  --set repoServer.autoscaling.minReplicas=2 \
  --set applicationSet.replicaCount=2

#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 30

echo "Installing root app..."
kubectl apply -f - <<EOF
# We generate this ArgoCD application with Terraform, but we keep it here as a workaround
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
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

#echo "Installing Prometheus"
#pushd prometheus-operator
#helm install prometheus-operator stable/prometheus-operator -f values.yaml
#popd
#
#echo "Installing InfluxDB"
#pushd influxdb
#helm install influxdb bitnami/influxdb -f ./values.yaml
#popd
#
#
#echo "Installing Redis and Grafana dashboards"
#pushd testground-infra
#helm dep build
#helm install testground-infra .
#popd

#echo "Install Weave service monitor..."
#echo
#
#kubectl apply -f ./kops-weave/weave-metrics-service.yml \
#              -f ./kops-weave/weave-service-monitor.yml

echo "Wait for Sidecar to be Ready..."
echo
RUNNING_SIDECARS=0
while [ "$RUNNING_SIDECARS" -ne "$WORKER_NODES" ]; do RUNNING_SIDECARS=$(kubectl get pods | grep testground-sidecar | grep Running | wc -l || true); echo "Got $RUNNING_SIDECARS running sidecar pods"; sleep 5; done;

echo "Testground cluster is installed"
echo

END_TIME=`date +%s`
echo "Execution time was `expr $END_TIME - $START_TIME` seconds"
