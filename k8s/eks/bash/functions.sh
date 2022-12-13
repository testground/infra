#!/bin/bash

# error log prep check
prep_log_dir(){ 
  mkdir -p $real_path/log/$start-log/
  mkdir -p $real_path/.cluster/
}

concat_availability_zone(){
  AVAILABILITY_ZONE=$REGION$AZ_SUFFIX
}

concat_stack_name(){
  stack_name=eksctl-$CLUSTER_NAME-cluster
}

wait_for_create(){
  while [[ $stack_state  == CREATE_IN_PROGRESS ]];do
  stack_state=$(aws cloudformation describe-stacks --region $REGION --stack-name $stack_name | jq -r ".Stacks[] | .StackStatus")
  echo "The cluster is still in $stack_state state, please wait. Next update in 30 seconds."
  sleep 30
  done
}

wait_for_delete(){
  while [[ $stack_state  == DELETE_IN_PROGRESS ]];do
  stack_state=$(aws cloudformation describe-stacks --region $REGION --stack-name $stack_name | jq -r ".Stacks[] | .StackStatus")
  if [[ -z "${stack_state}" ]]
  then
    echo -e "Your cluster $stack_name has been deleted.\n"
  else
    echo "The cluster is still in $stack_state state, please wait. Next update in 30 seconds."
    sleep 30
  fi
  done
}

delete_stack(){
  echo -e "\n"
  echo -e "Your cluster $stack_name is in FAILED state, removing the Cloudformation stack. Please wait.\n"
  aws cloudformation delete-stack --stack-name $stack_name --region $REGION
  stack_state=DELETE_IN_PROGRESS
  wait_for_delete
}

check_stack_state(){
  concat_stack_name
  echo -e "\n"
  echo -e "Checking the state of your cluster\n"
  stack_state=$(aws cloudformation describe-stacks --region $REGION --stack-name $stack_name | jq -r ".Stacks[] | .StackStatus" || true)
  if [[ -z "${stack_state}" ]]
  then
    echo -e "Your cluster $stack_name does not exist, proceeding to create it.\n"
    create_cluster
  elif  [[ $stack_state  == CREATE_COMPLETE ]]
  then
    echo -e "Your cluster $stack_name is healthy, skipping to the next step.\n"
  elif [[ $stack_state == ROLLBACK_COMPLETE ]]
  then
    delete_stack
  elif [[ $stack_state == DELETE_IN_PROGRESS ]]
  then
    wait_for_delete
  elif [[ $stack_state  == CREATE_IN_PROGRESS ]]
  then
    wait_for_create
  else
    echo -e "Your cluster $stack_name is in $stack_state state. Please check the AWS console for more details.\n"
  fi
}

create_cluster() {
  if test -f "$real_path/.cluster/$CLUSTER_NAME-$REGION.cs"; then
    echo "File $real_path/.cluster/$CLUSTER_NAME-$REGION.cs exists."
    echo -e "Please note that you cannot have two clusters with the same name in the same region.\nYou may either run the uninstall script first to remove the existing cluster, or select a different AWS region.\n"
    exit
fi
  eksctl create cluster --name $CLUSTER_NAME --without-nodegroup --region=$REGION
  echo "cluster_created=true" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
  echo "cluster_name=$CLUSTER_NAME" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
  echo "region=$REGION" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
}

deploy_multus_ds() {
  kubectl apply -f $real_path/yaml/multus-daemonset.yml
}

deploy_weave_cni() {
  #kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml
}

create_weave_networkattachmentdefinition() {
  kubectl apply -f $real_path/yaml/weave.yml
}

deploy_cluster_role_binding() {
  kubectl apply -f $real_path/yaml/clusterrolebinding.yml
}

weave_ip_tables_drop() {
  kubectl apply -f $real_path/yaml/drop-weave-cm.yml
  kubectl apply -f $real_path/yaml/drop-weave-ds.yml
}

multus_softlink() {
  kubectl apply -f $real_path/yaml/softlink-cm.yml
  kubectl apply -f $real_path/yaml/softlink-ds.yml
}

obtain_ami_id(){
  AMI_ID=$(aws ec2 describe-images --filters "Name=name,Values=$AMI_NAME" --owners amazon --region $REGION | jq -r '.Images[0].ImageId')
}

make_cluster_config(){
obtain_ami_id
concat_availability_zone
    cat <<EOT > $real_path/.cluster/$CLUSTER_NAME-$REGION.yaml
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
    ami: $AMI_ID
    desiredCapacity: $DESIRED_CAPACITY_INFRA
    volumeSize: $VOLUME_SIZE_INFRA
    privateNetworking: false
    availabilityZones: ["$AVAILABILITY_ZONE"]
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
        --use-max-pods=false
  - name: ng-2-plan
    labels:
      "testground.node.role.plan": "true"
    instanceType: $INSTANCE_TYPE_PLAN
    # Amazon EKS optimized Amazon Linux 2 v1.22 built on 08 Aug 2022
    ami: $AMI_ID
    desiredCapacity: $DESIRED_CAPACITY_PLAN
    volumeSize: $VOLUME_SIZE_PLAN
    privateNetworking: false
    availabilityZones: [$AVAILABILITY_ZONE]
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    preBootstrapCommands:
      - |
        sudo bash -c 'cat <<SYSCTL > /etc/sysctl.d/999-testground.conf
        fs.file-max = 3178504
        net.core.somaxconn = 131072
        net.netfilter.nf_conntrack_max = 1048576
        net.core.netdev_max_backlog = 524288
        net.core.rmem_max = 16777216
        net.core.wmem_max = 16777216
        net.ipv4.tcp_rmem = 16384 131072 16777216
        net.ipv4.tcp_wmem = 16384 131072 16777216
        net.ipv4.tcp_mem = 262144 524288 1572864
        net.ipv4.tcp_max_syn_backlog = 131072
        net.ipv4.ip_local_port_range = 10000 65535
        net.ipv4.tcp_tw_reuse = 1
        net.ipv4.ip_forward = 1
        net.ipv4.conf.all.rp_filter = 0
        net.ipv4.neigh.default.gc_thresh2 = 4096
        net.ipv4.neigh.default.gc_thresh3 = 32768
        SYSCTL'
      - "sudo sysctl -p /etc/sysctl.d/999-testground.conf"
      - |
        sudo bash -c 'cat <<LIMITS > /etc/security/limits.d/999-limits.conf
        *  soft  nproc  131072
        *  hard  nproc  262144
        *  soft  nofile 131072
        *  hard  nofile 262144
        LIMITS'
    # 234 is the max number of pods for c5.4xlarge
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh $CLUSTER_NAME \
       --kubelet-extra-args '--max-pods=234 --allowed-unsafe-sysctls=net.core.somaxconn' \
       --use-max-pods false
EOT
}

concat_ng_stack_name(){
  temp_ng_stack_name=$CLUSTER_NAME-nodegroup
}

obtain_ng_name(){
  concat_ng_stack_name
  readarray -t ng_stack_name < <(aws cloudformation describe-stacks --region $REGION --query "Stacks[?contains(StackName, '$temp_ng_stack_name')].StackName" | awk -F[\"\"] '{print $2}')
  if [[ -z "${ng_stack_name-}" ]]
  then
    ng_stack_name=null
  else
    echo -e "\n"
  fi
}

check_ng_stack_state(){
  obtain_ng_name
  echo -e "Checking the state of your nodegroups\n"
  if [[ "${ng_stack_name}" == "null" ]]
  then
    echo -e "No active nodegroups found in the selected region ($REGION), proceeding to create them.\n"
  else
    for stack_name in ${ng_stack_name[@]}; do
      stack_state=$(aws cloudformation describe-stacks --region $REGION --stack-name $stack_name | jq -r ".Stacks[] | .StackStatus")
      if [[ $stack_state == CREATE_COMPLETE  ]]
      then
        echo -e "Your nodegroup $stack_name is healthy, skipping to the next step.\n"
      elif [[ $stack_state == ROLLBACK_COMPLETE ]]
      then
        delete_stack
      elif [[ $stack_state == DELETE_IN_PROGRESS ]]
      then
        wait_for_delete
      elif [[ $stack_state  == CREATE_IN_PROGRESS ]]
      then
        wait_for_create
      else
        echo -e "Your nodegroup $stack_name is in $stack_state state. Please check the AWS console for more details.\n"
      fi
    done
  fi
}

create_node_group(){
  eksctl create nodegroup --config-file=$real_path/.cluster/$CLUSTER_NAME-$REGION.yaml
  echo "node_group_created=true" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
}

##### EFS and EBS #######

check_for_efs(){
  efs_id_temp=$(aws efs describe-file-systems --query "FileSystems[?Tags[?Key=='Name' && Value=='$CLUSTER_NAME']].FileSystemId" --region $REGION | awk -F[\"\"] '{print $2}')
  efs_id=$(echo $efs_id_temp|tr -d '\n')
}

check_for_ebs(){
  ebs_id_temp=$(aws ec2 describe-volumes --filters Name=tag:Name,Values=$CLUSTER_NAME --query "Volumes[*].VolumeId" --region $REGION | awk -F[\"\"] '{print $2}')
  ebs_id=$(echo $ebs_id_temp|tr -d '\n')
}

aws_create_file_system(){
  check_for_efs
  if [[ -z "$efs_id" ]]
  then
    echo -e "No EFS matching the criteria found in the selected region ($REGION), proceeding to create it.\n"
    create_efs=$(aws efs create-file-system --tags Key=Name,Value=$CLUSTER_NAME --region $REGION)
    echo "$create_efs"
    efs_fs_id=$(echo $create_efs | jq -r '.FileSystemId')
    aws efs tag-resource --resource-id $efs_fs_id --region $REGION --tags Key=alpha.eksctl.io/cluster-name,Value=$CLUSTER_NAME Key=Name,Value=$CLUSTER_NAME
    echo "efs=$efs_fs_id" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
    echo -e "EFS created with ID : $efs_fs_id\n"
  else
    echo "EFS already exists, skipping to the next step."
  fi
}

aws_get_vpc_id(){
  vpc_id=$(aws ec2 describe-vpcs --region $REGION --filters Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/VPC |jq -r ".Vpcs[] | .VpcId")
}

aws_get_subnet_id(){ 
  aws_get_vpc_id
  concat_availability_zone
  upper_az=$(echo $AVAILABILITY_ZONE | tr '[:lower:]' '[:upper:]' |  tr -d \-)
  subnet_id=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/SubnetPrivate$upper_az"  | jq  ".Subnets[] | select(.AvailabilityZone==\"$AVAILABILITY_ZONE\") | .SubnetId " | tr -d \" )
}

aws_get_sg_id(){
  aws_get_vpc_id
  efs_sg_id=$(aws ec2 describe-security-groups --region $REGION --filter Name=vpc-id,Values=$vpc_id Name=tag:Name,Values=eksctl-$CLUSTER_NAME-cluster/ClusterSharedNodeSecurityGroup --query 'SecurityGroups[*].[GroupId]' --output text)
}

aws_create_efs_mount_point(){
  mnt_target_id=$(aws efs describe-mount-targets --region $REGION --file-system-id $efs_fs_id | jq -r ".MountTargets[] | .MountTargetId")
  if [[ -z "${mnt_target_id}" ]]
  then
    aws efs create-mount-target --file-system-id $efs_fs_id --subnet-id $subnet_id --security-group $efs_sg_id --region $REGION
  fi
  efs_dns=$efs_fs_id.efs.$REGION.amazonaws.com
}

create_cm_efs(){
  if ! kubectl get configmap | grep --quiet efs-provisioner; then
    kubectl create configmap efs-provisioner --from-literal=file.system.id=$efs_fs_id --from-literal=aws.region=$REGION --from-literal=provisioner.name=testground.io/aws-efs
  fi
}

create_efs_manifest(){
  export EFS_DNSNAME="$efs_dns"
  export AWS_REGION="$REGION"
  export fsId="$efs_fs_id"

  EFS_MANIFEST_SPEC=$(mktemp)
  envsubst <$real_path/yaml/efs/manifest.yaml.spec >$EFS_MANIFEST_SPEC
  kubectl apply -f $real_path/yaml/efs/rbac.yaml -f $EFS_MANIFEST_SPEC
}

aws_create_ebs(){
  check_for_ebs
  concat_availability_zone
  if [[ -z "$ebs_id" ]]
  then
    echo -e "No EBS matching the criteria found in the selected region ($REGION), proceeding to create it.\n"
    create_ebs_volume=$(aws ec2 create-volume --size $EBS_SIZE --availability-zone $AVAILABILITY_ZONE)
    echo "$create_ebs_volume"
    ebs_volume=$(echo $create_ebs_volume | jq -r '.VolumeId' )
    aws ec2 create-tags --resources $ebs_volume --region $REGION --tags Key=alpha.eksctl.io/cluster-name,Value=$CLUSTER_NAME Key=Name,Value=$CLUSTER_NAME
    echo "ebs=$ebs_volume" >> $real_path/.cluster/$CLUSTER_NAME-$REGION.cs
    echo -e "EBS created with this volume ID: $ebs_volume\n"
  else
    echo "EBS already exists, skipping to the next step."
  fi  
}

make_persistent_volume(){  
  export TG_EBS_DATADIR_VOLUME_ID=$ebs_volume

  EBS_PV=$(mktemp)
  envsubst <$real_path/yaml/ebs/pv.yml.spec >$EBS_PV
  kubectl apply -f $real_path/yaml/ebs/storageclass.yml -f $EBS_PV -f $real_path/yaml/ebs/pvc.yml
}

helm_redis_add_repo(){
  helm repo add bitnami https://charts.bitnami.com/bitnami
} 

helm_infra_install_redis(){
  helm install testground-infra-redis --set auth.enabled=false --set master.nodeSelector='testground.node.role.infra: "true"' bitnami/redis
} 

helm_infra_install_influx_db(){
  helm install influxdb bitnami/influxdb -f $real_path/yaml/influxdb/values.yml --set image.tag=1.8.2 --set image.debug=true --version 2.6.1
} 

tg_daemon_config_map(){
  kubectl apply -f - <<EOF
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
    influxdb_endpoint = "http://influxdb:8086"

    [daemon.scheduler]
    workers = 2
    task_timeout_min  = 20
    task_repo_type    = "disk"

    [client]
    endpoint = "localhost:8080"

EOF
}

tg_daemon_service_account(){
  kubectl apply -f $real_path/yaml/tg-daemon-service-account.yml
}

tg_daemon_role_binding(){
  kubectl apply -f $real_path/yaml/tg-daemon-cluster-role.yml
}

tg_daemon_services(){
  export CLUSTER_NAME="$CLUSTER_NAME"

  TG_DAEMON_SVC=$(mktemp)
  envsubst <$real_path/yaml/tg-daemon-svc.yml.spec >$TG_DAEMON_SVC
  kubectl apply -f $TG_DAEMON_SVC
}

tg_daemon_svc_sync_service(){
  kubectl apply -f $real_path/yaml/tg-sync-service.yml
}

tg_daemon_sync_service(){
  kubectl apply -f $real_path/yaml/tg-sync-service-deployment.yml
}

tg_daemon_sidecar(){
  kubectl apply -f $real_path/yaml/tg-ds-sidecar.yml
}

tg_daemon_deployment(){
  kubectl apply -f $real_path/yaml/tg-daemon-deployment.yml
}

obtain_alb_address(){
  ALB_ADDRESS=$(kubectl get services -l app=testground-daemon -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")
}

obtain_alb_name(){
  ALB_NAME=$(kubectl get services -l app=testground-daemon -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}" | cut -d'-' -f1)
}

wait_for_alb_and_instances(){
  obtain_alb_name
  aws elb wait any-instance-in-service --load-balancer-name $ALB_NAME --region $REGION
}

echo_env_toml(){
  username=$(whoami)
  echo "Your 'testground/.env.toml' file needs to look like this:"
  echo -e "\n"
  echo "[aws]"
  echo "region = \"$REGION\""
  echo "[client]"
  echo "endpoint = 'http://$ALB_ADDRESS:80'"
  echo "user = '${username}'"
  echo -e "\n"
}

log(){
  tar czf $real_path/log/$start-$CLUSTER_NAME.tar.gz $real_path/log/$start-log/
  echo "========================"
  echo "Log file generated with name $start-$CLUSTER_NAME.tar.gz"
  echo -e "\n"
  rm -rf $real_path/log/$start-log/ 
}

##### Functions below are used by the 'testground_uninstall.sh' script #######

remove_efs_mp_timer(){ 
  efs_mp_state=available # setting the start value for the loop to consider
  sleep 15
  while [[ $efs_mp_state  == available ]];do 
    efs_mp_state=$(aws efs describe-mount-targets --file-system-id $efs --region $region | jq -r ".MountTargets[] | .LifeCycleState")
    sleep 1
    done 
}

remove_efs_fs_timer(){ 
  efs_fs_state=available # setting the start value for the loop to consider
  while [[ $efs_fs_state  == available ]];do 
    efs_fs_state=$(aws efs describe-file-systems --region $region --file-system-id $efs | jq -r ".FileSystems[] | .LifeCycleState")
    sleep 1
    done 
}

obtain_efs_id(){
  efs_id_temp=$(aws efs describe-file-systems --query "FileSystems[?Tags[?Key=='Name' && Value=='$cluster_name']].FileSystemId" --region $region | awk -F[\"\"] '{print $2}')
  efs_id=$(echo $efs_id_temp|tr -d '\n')
}

obtain_ebs_id(){
  ebs_id_temp=$(aws ec2 describe-volumes --filters Name=tag:Name,Values=$cluster_name --query "Volumes[*].VolumeId" --region $region | awk -F[\"\"] '{print $2}')
  ebs_id=$(echo $ebs_id_temp|tr -d '\n')
}

obtain_cluster_name(){
  readarray -t active_clusters < <(aws eks list-clusters --query clusters --output text --region $region)
  if [[ -z "${active_clusters-}" ]]
  then
    active_clusters=null
  else
    echo -e "\n"
  fi
}

cleanup(){
  efs_deleted=false
  ebs_deleted=false
  cluster_deleted=false

  obtain_efs_id
  obtain_cluster_name
  obtain_ebs_id
  echo -e "Removal process for the selection will start\n"
  if [[  -z "${efs:-}" ]]
  then
    echo -e "Looks like no EFS was created in this run. The EFS variable is empty.\nPlease check the '.cluster/$cluster_name-$region.cs' file and try again.\n"
  elif [ "$efs" == "$efs_id" ]
  then
    mnt_target_id=$(aws efs describe-mount-targets --region $region --file-system-id $efs | jq -r ".MountTargets[] | .MountTargetId")
    if [[ -z "${mnt_target_id-}" ]]
    then
      echo -e "No mount targets found in the selected region ($region). Skipping to the next step.\n"
    else
      echo "Removing mount target with ID $mnt_target_id"
      aws efs delete-mount-target --region $region --mount-target-id $mnt_target_id
      remove_efs_mp_timer
      echo -e "Mount target $mnt_target_id has been deleted.\n"
    fi
    echo "Now removing EFS $efs"
    aws efs delete-file-system --file-system $efs --region $region
    remove_efs_fs_timer
    echo -e "EFS $efs has been deleted.\n"
    efs_deleted=true
    echo "efs_deleted=true" >> $real_path/.cluster/$cluster_name-$region.cs
  else
    echo -e "Looks like the EFS ($efs) you have specified does not exist in the specified region ($region).\nIt is possible that it has already been deleted.\n"
  fi

  if [[  -z "${cluster_name:-}" ]]
  then
    echo -e "Looks like no cluster was created in this run. The cluster variable is empty.\nPlease check the '.cluster/$cluster_name-$region.cs' file and try again.\n"
  fi
  if [[ "${active_clusters}" == "null" ]]
  then
    echo -e "No active clusters found in the selected region ($region). Skipping to the next step.\n"
  else
    for i in ${active_clusters[@]}; do
      if [[ "$cluster_name" == "$i"  ]]
      then
        echo -e "Now removing the cluster $cluster_name, this may take some time\n"
        eksctl delete cluster --name $cluster_name --region $region --wait
        rm -f $real_path/.cluster/$cluster_name-$region.yaml
        cluster_deleted=true
        echo "cluster_deleted=true" >> $real_path/.cluster/$cluster_name-$region.cs
        echo -e "\n"
        break
      else
        echo -e "Looks like the cluster ($cluster_name) you have specified does not exist in the specified region ($region).\nIt is possible that it has already been deleted.\n"
      fi
    done
  fi

  if [[  -z "${ebs:-}" ]]
  then
    echo -e "Looks like no EBS was created in this run. The EBS variable is empty.\nPlease check the '.cluster/$cluster_name-$region.cs' file and try again.\n"
  elif [ "$ebs" == "$ebs_id" ]
  then
    echo -e "Now removing EBS: $ebs\n"
    aws ec2 delete-volume --volume-id $ebs --region $region
    aws ec2 wait volume-deleted --volume-id $ebs --region $region
    echo -e "Volume $ebs has been deleted.\n"
    ebs_deleted=true
    echo "ebs_deleted=true" >> $real_path/.cluster/$cluster_name-$region.cs
  else
    echo -e "Looks like the EBS you have specified ($ebs) does not exist in the selected region ($region).\nIt is possible that it has already been deleted.\n"
  fi
  
  if [ "$efs_deleted" == "true" ] && [ "$ebs_deleted" == "true" ] && [ "$cluster_deleted" == "true" ]
  then
    rm -f $real_path/.cluster/$cluster_name-$region.cs
    echo -e "Uninstall script completed and removed the '.cluster/$cluster_name-$region.cs' file.\n"
  else
    echo -e "Uninstall script completed, but did not remove the '.cluster/$cluster_name-$region.cs' file due to other resources not being deleted.\nPlease check the '.cluster/$cluster_name-$region.cs' file and try again.\n"
  fi
}