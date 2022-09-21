#!/bin/bash
set -e # Let's make sure that exit code 1 drops the script
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

source .env # Setting .env vars
echo "Log path is ./log/$start-log/cluster.log "
# Let's do a sanity check
if [ -n "$cluster_setup_init" ]; then
  echo "We found that you already have a cluster provisioned with this script"
  read -p "Do you want to remove it? (y/n)?" choice
  case "$choice" in 
  y|Y ) cleanup;;
  n|N ) exit;;
  * ) echo "invalid selection";;
  esac
  exit 1
fi

if [[ "$CLUSTER_NAME" == "default" ]]
 then
   echo "Your cluster name can't be "default" " 
   echo "Please edit the .env file, which is located in the same directory as this script."
   exit 1
else
  echo "Creating cluster with name: $CLUSTER_NAME "
  echo "Please note, this can take up to 20 minutes to complete." 
  create_cluster >> ./log/$start-log/cluster.log
  echo "========================"
  echo ""
fi

echo "Now deploying multus-cni daemonset"
deploy_multus_ds >> ./log/$start-log/cluster.log
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
   echo "Calico - weave combination is selected."
   echo "Removing aws_node daemonset" 
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
  echo "CNI_COMBINATION can't be $CNI_COMBINATION" >> ./log/$start-log/erorr.log
  echo "Options are calico_weave or aws_vpc_cni_weave"
  echo "========================"
  exit 1
fi

echo "Applying and creating weave network attachment"
apply_weave >> ./log/$start-log/cluster.log
create_weave >> ./log/$start-log/cluster.log
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
  echo "Deploying calico and multus daemonset"
 # deploy_vpc_weave_multusds >> ./log/$start-log/cluster.log
  deploy_vpc_multus_cm_calico >> ./log/$start-log/cluster.log
  echo "========================"
 elif [[ "$CNI_COMBINATION" == "aws_vpc_cni_weave" ]]
  then
  echo "aws_vpc_cni_weave combination is selected."
else
  echo "Deploying multus daemonset and selected CNI failed" >> ./log/$start-log/erorr.log
  echo "exiting" >> ./log/$start-log/erorr.log
  echo "========================"
  exit 1
fi

echo "Now setting role binding..."
deploy_cluster_role_binding >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Dropping weave iptables rule..."
weave_ip_tables_drop >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Making multus softlink..."
multus_softlink >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating cluster config file with name $CLUSTER_NAME.yaml"
make_cluster_config >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating nodegroup now, this can also take some time..."
create_node_group >> ./log/$start-log/cluster.log
echo "========================"
echo ""
echo "Now configuring storage.."
echo ""
echo "Let's check utility..."
jq_check >> ./log/$start-log/cluster.log
echo "Creating EFS (Elastic File System)..."
aws_create_file_system >> ./log/$start-log/cluster.log
echo "EFS created with ID : $efs_fs_id "
echo ""
echo "Now extracting subnet group ID..."
aws_get_subnet_id >> ./log/$start-log/cluster.log
echo "Subnet group ID: $subnet_id"
echo ""
# echo "Now extracting CIDR block..."
# aws_get_subnet_cidr_block >> ./log/$start-log/cluster.log
# echo "CIDR block is: $subnet_cidr_block"
# echo ""
# echo "Creating security group for EFS..."
# aws_create_efs_sg >> ./log/$start-log/cluster.log
# echo "EFS security group created with ID: $efs_sg_id"
# echo ""
# echo "Now authorising subnet CIDR block $subnet_cidr_block to access $efs_sg_id "
# aws_efs_sg_rule_add >> ./log/$start-log/cluster.log
aws_get_sg_id >> ./log/$start-log/cluster.log
echo "Done."
echo ""

echo "Creating EFS mount point"
aws_create_efs_mount_point >> ./log/$start-log/cluster.log
echo "Your EFS mountpoint DNS is: $efs_dns"
echo ""
echo "Now creating EFS configmap"
create_cm_efs >> ./log/$start-log/cluster.log
echo ""
echo "Now creating EFS manifest"
create_efs_manifest >> ./log/$start-log/cluster.log

echo "========================"
echo ""
echo ""

echo "Creating EBS volume (Elastic Block Store)"
aws_create_ebs >> ./log/$start-log/cluster.log
echo "EBS created with this volume ID: $ebs_volume "
echo ""
echo "Now making persistent volume on EKS"
make_persistent_volume >> ./log/$start-log/cluster.log
echo "Done."
echo "========================"

echo "Setting up Redis..."
helm_redis_add_repo >> ./log/$start-log/cluster.log
echo "Helm Redis repo added"
echo "Now proceeding with Helm install"
helm_infra_install_redis >> ./log/$start-log/cluster.log
echo "Redis installed"
echo "========================"
echo "We will setup the testground daemon now."
echo ""
echo ""
echo "Creating configmap..."
tg_daemon_config_map >> ./log/$start-log/cluster.log
echo "Creating service account..."
tg_daemon_service_account >> ./log/$start-log/cluster.log
echo "Creating role binding..."
tg_daemon_role_binding >> ./log/$start-log/cluster.log
echo "Creating the testground service.."
tg_daemon_services >> ./log/$start-log/cluster.log
echo "Creating svc sync service..."
tg_daemon_svc_sync_service >> ./log/$start-log/cluster.log
echo "Creating sync service deployment..."
tg_daemon_sync_service >> ./log/$start-log/cluster.log
echo "Creating sidecar..."
tg_daemon_sidecar >> ./log/$start-log/cluster.log
echo "Creating testground daemon deployment..."
tg_daemon_deployment >> ./log/$start-log/cluster.log

echo "========================"
echo ""
echo ""
echo "Your cluster is ready to be used."
echo ""
log
echo "Log for this build can be fonud on this path ./log/$start-$CLUSTER_NAME-$CNI_COMBINATION.tar.gz"