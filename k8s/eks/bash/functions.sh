#!/bin/bash

# error log prep check
prep_log_dir(){ 
mkdir -p ./log/$start-log/
}

create_cluster() {
  eksctl create cluster --name $CLUSTER_NAME --without-nodegroup --region=$REGION
  echo "cluster_setup_init=true" >> ./.env
}

remove_aws_node_ds() {
    kubectl delete daemonset -n kube-system aws-node
}

deploy_multus_ds() {
    kubectl apply -f ./yaml/multus-daemonset.yml
}

apply_weave() {
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
}

create_weave() {
    kubectl create -f ./yaml/weave.yml
}

deploy_cluster_role_binding() {
    kubectl create clusterrolebinding service-reader --clusterrole=service-reader --serviceaccount=default:default
    kubectl create -f ./yaml/clusterrolebinding.yml
}

weave_ip_tables_drop() {
    kubectl create -f ./yaml/drop-weave-cm.yml
    kubectl create -f ./yaml/drop-weave-ds.yml
}

multus_softlink() {
    kubectl create -f ./yaml/softlink-cm.yml
    kubectl create -f ./yaml/softlink-ds.yml
}

make_cluster_config(){
    cat <<EOT >> ./$CLUSTER_NAME.yaml
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
    desiredCapacity: $DESIRED_CAPACITY_INFRA
    volumeSize: $VOLUME_SIZE_INFRA
    privateNetworking: false
    availabilityZones: ["$AVAILABILITY_ZONE"]
    # ssh:
    #   allow: true
    #   # key needs to exist
    #   publicKeyPath: $SSH_PATH_INFRA
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
    desiredCapacity: $DESIRED_CAPACITY_PLAN
    volumeSize: $VOLUME_SIZE_PLAN
    privateNetworking: false
    availabilityZones: [$AVAILABILITY_ZONE]
    # ssh:
    #   allow: true
    #   publicKeyPath: $SSH_PATH_PLAN
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

jq_check(){ 
has_jq_installed=$(which jq)
if [[ "$OSTYPE" == "linux-gnu"* ]]
 then
   if [ -z $has_jq_installed ]
     then
       sudo apt update
       sudo apt install jq
   else
       echo ""
   fi
   else
       echo "Unsupported operating system. This will work for 'linux-gnu'." 
 fi
}

create_node_group(){
    eksctl create nodegroup --config-file=$CLUSTER_NAME.yaml
}

##### EFS and EBS #######

aws_create_file_system(){
    create_efs=$(aws efs create-file-system --tags Key=Name,Value=$CLUSTER_NAME --region $REGION)
    echo "$create_efs"
    efs_fs_id=$(echo $create_efs | jq -r '.FileSystemId')
    echo "efs=$efs_fs_id" >> ./.env
}

aws_get_vpc_id(){
  vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/VPC |jq -r ".Vpcs[] | .VpcId")
}

aws_get_subnet_id(){ 
    aws_get_vpc_id
    upper_az=$(echo $AVAILABILITY_ZONE | tr '[:lower:]' '[:upper:]' |  tr -d \-)
    subnet_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/SubnetPrivate$upper_az"  | jq  ".Subnets[] | select(.AvailabilityZone==\"$AVAILABILITY_ZONE\") | .SubnetId " | tr -d \" )
}

# aws_get_subnet_cidr_block(){
#     upper_az=$(echo $AVAILABILITY_ZONE | tr '[:lower:]' '[:upper:]' |  tr -d \-)
#     subnet_cidr_block=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id"  "Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/SubnetPrivate$upper_az" | jq  ".Subnets[] | select(.AvailabilityZone==\"$AVAILABILITY_ZONE\") | .CidrBlock " | tr -d \" )

# }
# aws_create_efs_sg(){
#     create_efs_sg=$(aws ec2 create-security-group --region $REGION --vpc-id $vpc_id --group-name efs-$CLUSTER_NAME-sg  --description "Security group crreated by testground eks automation script" )
#     echo "$create_efs_sg"
#     efs_sg_id=$(echo $create_efs_sg | jq -r '.GroupId')
# }

# aws_efs_sg_rule_add(){
#     aws ec2 authorize-security-group-ingress --group-id $efs_sg_id --protocol tcp --port 2049 --cidr $subnet_cidr_block
# }

aws_get_sg_id(){
  aws_get_vpc_id
  efs_sg_id=$(aws ec2 describe-security-groups --region $REGION --filter Name=vpc-id,Values=$vpc_id Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/ClusterSharedNodeSecurityGroup --query 'SecurityGroups[*].[GroupId]' --output text)
}

aws_create_efs_mount_point(){
    aws efs create-mount-target --file-system-id $efs_fs_id --subnet-id $subnet_id --security-group $efs_sg_id --region $REGION
    efs_dns=$efs_fs_id.efs.$REGION.amazonaws.com
   
}

create_cm_efs(){
  kubectl create configmap efs-provisioner --from-literal=file.system.id=$efs_fs_id --from-literal=aws.region=$REGION --from-literal=provisioner.name=testground.io/aws-efs
}

create_efs_manifest(){
    export EFS_DNSNAME="$efs_dns"
    export AWS_REGION="$REGION"
    export fsId="$efs_fs_id"

    EFS_MANIFEST_SPEC=$(mktemp)
    envsubst <../kops/efs/manifest.yaml.spec >$EFS_MANIFEST_SPEC
    kubectl apply -f ../kops/efs/rbac.yaml -f $EFS_MANIFEST_SPEC
}

aws_create_ebs(){
  create_ebs_volume=$(aws ec2 create-volume --size $EBS_SIZE  --availability-zone $AVAILABILITY_ZONE)
  echo "$create_ebs_volume"
  ebs_volume=$(echo $create_ebs_volume | jq -r '.VolumeId' )
  echo "ebs=$ebs_volume" >> ./.env
}

make_persistent_volume(){  
export TG_EBS_DATADIR_VOLUME_ID=$ebs_volume
EBS_PV=$(mktemp)
envsubst <../kops/ebs/pv.yml.spec >$EBS_PV
kubectl apply -f ../kops/ebs/storageclass.yml -f $EBS_PV -f ../kops/ebs/pvc.yml
}

helm_redis_add_repo(){
  helm repo add bitnami https://charts.bitnami.com/bitnami
} 

helm_infra_install_redis(){
  helm install testground-infra-redis --set auth.enabled=false --set master.nodeSelector='testground.node.role.infra: "true"' bitnami/redis
} 

# Until we find a better way for region var
# tg_daemon_config_map(){
#   kubectl apply -f ../kops/testground-daemon/config-map-env-toml.yml
# } | tee -a ./log/$start-log/tg_daemon_config_map.log

tg_daemon_config_map(){
  kubectl create -f - <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: env-toml-cfg
  namespace: default
data:
  .env.toml: |
    ["aws"]
    region = "$REGION"   

    [runners."cluster:k8s"]
    run_timeout_min             = 15
    testplan_pod_cpu            = "100m"
    testplan_pod_memory         = "100Mi"
    collect_outputs_pod_cpu     = "1000m"
    collect_outputs_pod_memory  = "1000Mi"
    provider                    = "aws"
    sysctls = [
      "net.core.somaxconn=10000",
    ]

    [daemon]
    listen = "0.0.0.0:8042"
    slack_webhook_url = ""
    github_repo_status_token = ""

    [daemon.scheduler]
    workers = 2
    task_timeout_min  = 20
    task_repo_type    = "disk"

    [client]
    endpoint = "localhost:8080"

EOF
}

tg_daemon_service_account(){
  kubectl apply -f ./yaml/tg-daemon-service-account.yml
}

tg_daemon_role_binding(){
  kubectl apply -f ./yaml/tg-daemon-cluster-role.yml
}

tg_daemon_services(){
  kubectl apply -f ./yaml/tg-testground-daemon-service.yml
}

tg_daemon_svc_sync_service(){
  kubectl apply -f ./yaml/tg-sync-service.yml
}

tg_daemon_sync_service(){
  kubectl apply -f ./yaml/tg-sync-service-deployment.yml
}

tg_daemon_sidecar(){
  kubectl apply -f ./yaml/tg-ds-sidecar.yml
}

tg_daemon_deployment(){
  kubectl apply -f ./yaml/tg-daemon-deployment.yml
}

log(){
  tar czf ./log/$start-$CLUSTER_NAME-$CNI_COMBINATION.tar.gz /log/$start-log/
  echo "##########################################"
  echo "Log file generated with name $start-$CLUSTER_NAME-$CNI_COMBINATION.tar.gz"
  echo "##########################################"
  rm -rf ./log/$start-log/ 
}

# cluster_creation_manifest(){
#   mkdir -p .cluster_manifest
#   echo "$CLUSTER_NAME" >> clusters
# }

cleanup(){
  mnt_target_id=$(aws efs describe-mount-targets --file-system-id $efs | jq -r ".MountTargets[] | .MountTargetId")
  echo "Removing mount target with ID $mnt_target_id"
  echo "The script will pause here for 20 seconds for the removal to complete"
  aws efs delete-mount-target --mount-target-id $mnt_target_id
  sleep 20
  echo "Now removing EFS $efs"
  aws efs delete-file-system --file-system $efs
  echo "The script will pause here for additional 20 seconds"
  sleep 20
  echo "Now removing cluster, this may take some time"
  eksctl delete cluster --name $CLUSTER_NAME
  echo "Now removing EBS: $ebs"
  aws ec2 delete-volume --volume-id $ebs
  rm -f ./$CLUSTER_NAME.yaml
  echo "Now fixing the .env file for the next usage"
  head -n -3 .env >> .env.tmp && mv .env.tmp .env
}