#!/bin/bash
set -e # Let's make sure that exit code 1 drops the script
start=$(date +"%Y-%m-%d-%T")
cd "$(dirname "$0")"
real_path=$(/bin/pwd)

source $real_path/bash/functions.sh
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

source $real_path/.env # Setting .env vars
echo "Log path is $real_path/log/$start-log/cluster.log "
# Let's do a sanity check
if [ -n "$cluster_setup_init" ]; then
  echo "We found that you already have a cluster provisioned with this script"
  read -p "Do you want to remove it? (y/n)?" choice
  case "$choice" in 
  y|Y ) cleanup;;
  n|N ) exit;;
  * ) echo "invalid selection";;
  esac
  exit
fi

if [[ "$CLUSTER_NAME" == "" ]]
 then
   echo "Your cluster name can't be empty. " 
   echo "Please edit the .env file, which is located in the same directory as this script."
   exit 1
else
  echo "Creating cluster with name: $CLUSTER_NAME "
  echo "Please note, this can take up to 20 minutes to complete." 
  create_cluster >> $real_path/log/$start-log/cluster.log
  echo "========================"
  echo ""
fi

echo "Now deploying multus-cni daemonset"
deploy_multus_ds >> $real_path/log/$start-log/cluster.log
echo "========================"

if [[ "$CNI_COMBINATION" == "aws_vpc_cni_weave" ]]
  then
  echo "aws_vpc_cni_weave combination is selected."
else
  echo "Invalid selecton in .env"  >> $real_path/log/$start-log/erorr.log
  echo "CNI_COMBINATION can't be $CNI_COMBINATION" >> $real_path/log/$start-log/erorr.log
  echo "CNI combination must be aws_vpc_cni_weave."
  echo "========================"
  exit 1
fi

echo "Deploying the weave CNI to the cluster and creating the weave NetworkAttachmentDefinition"
deploy_weave_cni >> $real_path/log/$start-log/cluster.log
create_weave_networkattachmentdefinition >> $real_path/log/$start-log/cluster.log
echo "========================"

echo "Now setting role binding..."
deploy_cluster_role_binding >> $real_path/log/$start-log/cluster.log
echo "========================"
echo ""
echo "Dropping weave iptables rule..."
weave_ip_tables_drop >> $real_path/log/$start-log/cluster.log
echo "========================"
echo ""
echo "Making multus softlink..."
multus_softlink >> $real_path/log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating cluster config file with name $CLUSTER_NAME.yaml"
make_cluster_config >> $real_path/log/$start-log/cluster.log
echo "========================"
echo ""
echo "Creating nodegroup now, this can also take some time..."
create_node_group >> $real_path/log/$start-log/cluster.log
echo "========================"
echo ""
echo "Now configuring storage.."
echo ""
echo "Creating EFS (Elastic File System)..."
aws_create_file_system >> $real_path/log/$start-log/cluster.log
echo "EFS created with ID : $efs_fs_id "
echo ""
echo "Now extracting subnet group ID..."
aws_get_subnet_id >> $real_path/log/$start-log/cluster.log
echo "Subnet group ID: $subnet_id"
echo ""
aws_get_sg_id >> $real_path/log/$start-log/cluster.log
echo "Done."
echo ""

echo "Creating EFS mount point"
aws_create_efs_mount_point >> $real_path/log/$start-log/cluster.log
echo "Your EFS mountpoint DNS is: $efs_dns"
echo ""
echo "Now creating EFS configmap"
create_cm_efs >> $real_path/log/$start-log/cluster.log
echo ""
echo "Now creating EFS manifest"
create_efs_manifest >> $real_path/log/$start-log/cluster.log

echo "========================"
echo ""
echo ""

echo "Creating EBS volume (Elastic Block Store)"
aws_create_ebs >> $real_path/log/$start-log/cluster.log
echo "EBS created with this volume ID: $ebs_volume "
echo ""
echo "Now making persistent volume on EKS"
make_persistent_volume >> $real_path/log/$start-log/cluster.log
echo "Done."
echo "========================"

echo "Setting up Redis..."
helm_redis_add_repo >> $real_path/log/$start-log/cluster.log
echo "Helm Redis repo added"
echo "Now proceeding with Helm install"
helm_infra_install_redis >> $real_path/log/$start-log/cluster.log
echo "Redis installed"
echo "========================"
echo "We will setup the testground daemon now."
echo ""
echo ""
echo "Creating configmap..."
tg_daemon_config_map >> $real_path/log/$start-log/cluster.log
echo "Creating service account..."
tg_daemon_service_account >> $real_path/log/$start-log/cluster.log
echo "Creating role binding..."
tg_daemon_role_binding >> $real_path/log/$start-log/cluster.log
echo "Creating the testground service.."
tg_daemon_services >> $real_path/log/$start-log/cluster.log
echo "Creating svc sync service..."
tg_daemon_svc_sync_service >> $real_path/log/$start-log/cluster.log
echo "Creating sync service deployment..."
tg_daemon_sync_service >> $real_path/log/$start-log/cluster.log
echo "Creating sidecar..."
tg_daemon_sidecar >> $real_path/log/$start-log/cluster.log
echo "Creating testground daemon deployment..."
tg_daemon_deployment >> $real_path/log/$start-log/cluster.log

echo "========================"
echo ""
obtain_alb_address
echo_env_toml
echo ""
echo "Your cluster is ready to be used."
echo ""
echo ""
log
echo "Log for this build can be fonud on this path $real_path/$start-$CLUSTER_NAME-$CNI_COMBINATION.tar.gz"