#!/bin/bash
create_cluster() {
    eksctl create cluster --name $CLUSTER_NAME --without-nodegroup --region=$REGION
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


make_cluster_config(){
    cat <<EOT >> /$CLUSTER_NAME.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $CLUSTER_NAME
  region: $REGION
managedNodeGroups:
  - name: ng-1-infra
    labels:
      "testground.node.role.infra": "true"
    instanceType: $INSTANCE_TYPE_INFRA
    ami: $AMI_INFRA
    desiredCapacity: $DESIRED_CAPACIY_INFRA
    volumeSize: $VOLUME_SIZE_INFRA
    privateNetworking: false
    availabilityZones: ["$AVAILAVILITY_ZONES_INFRA"]
    ssh:
      allow: true
      # key needs to exist
      publicKeyPath: $SSH_PATH_INFRA
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
   
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh $CLUSTER_NAME \
        --kubelet-extra-args '--max-pods=58' \
        --use-max-pods false
  - name: ng-2-plan
    labels:
      "testground.node.role.plan": "true"
    instanceType: $INSTANCE_TYPE_PLAN 
    # Amazon EKS optimized Amazon Linux 2 v1.22 built on 08 Aug 2022
    ami: $AMI_PLAN
    desiredCapacity: $DESIRED_CAPACIY_PLAN
    volumeSize: $VOLUME_SIZE_PLAN
    privateNetworking: false
    availabilityZones: [$AVAILAVILITY_ZONES_PLAN]
    ssh:
      allow: true
      publicKeyPath: $SSH_PATH_PLAN
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    preBootstrapCommands:
      - "echo -e 'fs.file-max=3178504\nnet.core.somaxconn = 131072\nnet.netfilter.nf_conntrack_max = 1048576\nnet.core.netdev_max_backlog = 524288\nnet.core.rmem_max = 16777216\nnet.core.wmem_max = 16777216\nnet.ipv4.tcp_rmem = 16384 131072 16777216\nnet.ipv4.tcp_wmem = 16384 131072 16777216\nnet.ipv4.tcp_mem = 262144 524288 1572864\nnet.ipv4.tcp_max_syn_backlog = 131072\nnet.ipv4.ip_local_port_range = 10000 65535\nnet.ipv4.tcp_tw_reuse = 1\nnet.ipv4.ip_forward = 1\nnet.ipv4.conf.all.rp_filter = 0\nnet.ipv4.neigh.default.gc_thresh2 = 4096\nnet.ipv4.neigh.default.gc_thresh3 = 32768' >> /tmp/999-testground.conf; sudo cp /tmp/999-testground.conf /etc/sysctl.d/999-testground.conf; sudo sysctl -p /etc/sysctl.d/999-testground.conf; echo -e '*  soft  nproc  131072\n*  hard  nproc  262144\n*  soft  nofile 131072\n*  hard  nofile 262144' >> /tmp/999-limits.conf; sudo cp /tmp/999-limits.conf /etc/security/limits.d/999-limits.conf"
    # 234 is the max number of pods for c5.4xlarge
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh $CLUSTER_NAME \
       --kubelet-extra-args '--max-pods=234' \
       --use-max-pods false
EOT
}

create_cluster(){
    eksctl create nodegroup --config-file=$CLUSTER_NAME.yaml
}  | tee -a ./log/$start-log/create_cluster.log

#####Aws cli part#######
aws_create_file_system(){
    create-file-system --region $REGION --availability-zone-name $AVAILAVILITY_ZONES_INFRA #first find out cluster avialbility zone
} | tee -a ./log/$start-log/aws-cli.log