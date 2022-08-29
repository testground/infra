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
    kubectl apply ./multus-cni/deployments/multus-daemonset.yml
} | tee -a ./log/$start-log/deploy_multus_ds.log

clone_multus() {
    git clone https://github.com/k8snetworkplumbingwg/multus-cni.git
} | tee -a ./log/$start-log/deploy_multus_ds.log

apply_weave() {
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
} | tee -a ./log/$start-log/apply_weave.log

create_weave() {
    kubectl create -f ./yaml/weave.yml
} | tee -a ./log/$start-log/create_weave.log


#Not used until we have aws vpc cni ready
deploy_multus_cm_vpc_cni() {
    kubectl create -f ./yaml/multus-cm-vpc-cni.yaml
} | tee -a ./log/$start-log/deploy_multus_cm_vpc_cni.log

deploy_vpc_weave_multusds() {
    kubectl create -f ./yaml/vpc-weave-multusds.yaml
} | tee -a ./log/$start-log/vpc_weave_multusds.log


deploy_vpc_multus_cm_calico() {
    kubectl create -f ./yaml/multus-cm-calico.yaml
} | tee -a ./log/$start-log/deploy_vpc_multus_cm_calico.log

deploy_cluster_role_binding() {
    kubectl create clusterrolebinding service-reader --clusterrole=service-reader --serviceaccount=default:default
    kubectl create -f ./yaml/clusterrolebinding.yml
} | tee -a ./log/$start-log/deploy_cluster_role_binding.log

weave_ip_tables_drop() {
    kubectl create -f ./yaml/drop-weave-cm.yml
    kubectl create -f ./yaml/drop-weave-ds.yml
} | tee -a ./log/$start-log/weave_ip_tables_drop.log

multus_soflink() {
    kubectl create -f ./yaml/soflink-cm.yml
    kubectl create -f ./yaml/drop-weave-ds.yml
} | tee -a ./log/$start-log/multus_soflink.log