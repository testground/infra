#!/bin/bash
set -e #lets make sure that exit code 1 drops the script
start=$(date +"%Y-%m-%d-%T")
source ./bash/functions.sh
prep_log_dir
cat << "EOF"
 _____         _   _____                           _ 
|_   _|       | | |  __ \                         | |
  | | ___  ___| |_| |  \/_ __ ___  _   _ _ __   __| |
  | |/ _ \/ __| __| | __| '__/ _ \| | | | '_ \ / _` |
  | |  __/\__ \ |_| |_\ \ | | (_) | |_| | | | | (_| |
  \_/\___||___/\__|\____/_|  \___/ \__,_|_| |_|\__,_|
                  EKS setup script 


EOF

source .env #setting .env vars
echo "Log path is ./log/$start-log/cluster.log "
#Lets do sanity check
if [[ "$CLUSTER_NAME" == "default" ]]
 then
   echo "Your cluster name cant be "default" " 
   echo "Please edit .env which is located in the same directory as this script"
   exit 1
else
  echo "Creating cluster with name: $CLUSTER_NAME "
  echo "Please note, this can take up to 20 minutes to complete." 
  create_cluster >> ./log/$start-log/cluster.log
  echo "========================"
  echo ""
fi

echo "Now deploying multus-cni DS"
deploy_multus_ds >> ./log/$start-log/cluster.log
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
   echo "Calico - weave combination is selected."
   echo "Removing aws_node DS" 
   remove_aws_node_ds >> ./log/$start-log/cluster.log
   echo "Adding tigera operator"
   add_tigera_operator >> ./log/$start-log/cluster.log
   echo "Deploying tigera operator"
   deploy_tigera_operator >> ./log/$start-log/cluster.log
   echo "========================"
elif [[ "$CNI_COMBINATION" == "aws_vpc_cni_weave" ]]
  then
  echo "aws_vpc_cni_weave combination is selected."
else
  echo "Invalid selecton in .env"  >> ./log/$start-log/erorr.log
  echo "CNI_COMBINATION cant be $CNI_COMBINATION" >> ./log/$start-log/erorr.log
  echo "Option are calico_weave or aws_vpc_cni_weave"
  echo "========================"
  exit 1
fi

echo "Applying and creating weave network attachment"
apply_weave >> ./log/$start-log/cluster.log
create_weave >> ./log/$start-log/cluster.log
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
  echo "Deploying calico and multus DS"
  deploy_vpc_weave_multusds >> ./log/$start-log/cluster.log
  deploy_vpc_multus_cm_calico >> ./log/$start-log/cluster.log
  echo "========================"
else
  echo "Deploying multus DS and selected cni failed" >> ./log/$start-log/erorr.log
  echo "exiting" >> ./log/$start-log/erorr.log
  echo "========================"
  exit 1
fi

echo "Now setging role binding..."
deploy_cluster_role_binding >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Droping weave ip table rule..."
weave_ip_tables_drop >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Making multus softlink..."
multus_soflink >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating cluster config file with name $CLUSTER_NAME.yaml"
make_cluster_config >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating node group now..."
create_node_group >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "now configuring storage.."
echo ""
echo "lets check uitlity.."
jq_check >> ./log/$start-log/cluster.log
echo "creating efs file-system.."
aws_create_file_system >> ./log/$start-log/cluster.log
echo "efs file system created with id : $efs_fs_id "
echo ""
echo "creating security group for efs..."
aws_create_efs_sg >> ./log/$start-log/cluster.log
echo "efs security group created with id: $efs_sg_id"
echo ""
echo "now extracting subnet group id...."
aws_get_subent_id >> ./log/$start-log/cluster.log
echo "subnet group id: $subnet_id"
echo ""
echo "now extractin cidr block..."
aws_get_subent_cidr_block >> ./log/$start-log/cluster.log
echo "Cidr block is: $subnet_cidr_block"
echo ""
echo "Now authorising subnet cidr block $subnet_cidr_block to access $efs_sg_id "
aws_efs_sg_rule_add >> ./log/$start-log/cluster.log
echo "done"
echo ""
echo "Creating efs mount point"
aws_create_efs_mount_point >> ./log/$start-log/cluster.log
echo "Your efs mountpoint dns is: $efs_dns"
echo ""
echo "now creating efs manifest"
create_efs_manifest >> ./log/$start-log/cluster.log

echo "========================"
echo ""
echo ""

echo "Creating ebs volume"
aws_create_ebs >> ./log/$start-log/cluster.log
echo "efs created with this volume id: $ebs_volume "
echo ""
echo "now making persistant volume on eks"
make_persistant_volume >> ./log/$start-log/cluster.log
echo "done"
echo "========================"

echo "Seting up redis..."
helm_redis_add_repo ./log/$start-log/cluster.log
echo "helm redis repo added"
echo "now proceding helm install"
helm_infra_install_redis ./log/$start-log/cluster.log
echo "redis installed"
echo "========================"
echo "We will setup the test-ground daemon now."
echo ""
echo ""
echo "creating config map now..."
tg_daemon_config_map >> ./log/$start-log/cluster.log
echo "creating service account..."
tg_daemon_service_account >> ./log/$start-log/cluster.log
echo "creating role binding..."
tg_daemon_role_binding >> ./log/$start-log/cluster.log
echo "creating services.."
tg_daemon_services >> ./log/$start-log/cluster.log
echo "creating svc sync service..."
tg_daemon_svc_sync_service >> ./log/$start-log/cluster.log
echo "creating sync sevice..."
tg_daemon_sync_service >> ./log/$start-log/cluster.log
echo "creating sidecar..."
tg_daemon_sidecar >> ./log/$start-log/cluster.log
echo "create deployment"
tg_daemon_deployment >> ./log/$start-log/cluster.log

echo "========================"
echo ""
echo ""
echo "Your cluster is ready to be used"