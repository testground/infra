#!/bin/bash
create_cluster() {
    eksctl create cluster --name $CLUSTER_NAME --without-nodegroup --region=$REGION<
} | tee -a ./log/$start-log/create_cluster.log

remove_aws_node_ds() {
    kubectl delete daemonset -n kube-system aws-node
} | tee -a ./log/$start-log/remove_aws_node_ds.log

add_tigera_operator() {
    kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
} | tee -a ./log/$start-log/add_tigera_operator.log

deploy_tigera_operator() {
    kubectl create -f ./yaml/tigera.yml
} | tee -a ./log/$start-log/deploy_tigera_operator.log

deploy_multus_ds() {
    kubectl apply ./multus-cni/deployments/multus-daemonset.ym
} | tee -a ./log/$start-log/deploy_multus_ds.log

clone_multus() {
    git clone https://github.com/k8snetworkplumbingwg/multus-cni.git
} | tee -a ./log/$start-log/deploy_multus_ds.log