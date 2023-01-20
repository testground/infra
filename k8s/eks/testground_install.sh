#!/usr/bin/env bash
# Let's make sure to check for exit code 1, undefined variables, or masked pipeline errors; if encountered, drop the script
set -euo pipefail
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
echo -e "\n"
echo "========================"
echo "PLEASE NOTE:"
echo "Running resources on AWS costs money."
echo "This script will create the following resources required for Testground:"
echo "  - 3 Cloudformation stacks created by eksctl - EKS cluster and 2 Nodegroups"
echo "(Note: if you edited the eksctl config file to add more than the default 2 nodegroups, then there will be more stacks)"
echo "  - EBS (Elastic Block Storage) volume in the selected Availability Zone"
echo "  - EFS (Elastic File System) in the selected AWS Region, along with a EFS mount target for the selected Availability Zone"
echo "Once the script finishes, you will be able to verify everything through the AWS console."
echo -e "========================\n"

source $real_path/.env # Setting .env vars
echo -e "Log path is $real_path/log/$start-log/cluster.log \n"

if [[ "$CLUSTER_NAME" == "" ]]
 then
   echo "Your cluster name can't be empty. " 
   echo "Please edit the .env file, which is located in the same directory as this script."
   exit 1
else
  echo "Creating cluster with name: $CLUSTER_NAME in region $REGION."
  echo "Please note, this can take up to 20 minutes to complete." 
  check_stack_state &>> $real_path/log/$start-log/cluster.log
  echo -e "========================\n"
fi

echo "Now deploying multus-cni daemonset"
deploy_multus_ds &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Deploying the weave CNI to the cluster and creating the weave NetworkAttachmentDefinition"
deploy_weave_cni &>> $real_path/log/$start-log/cluster.log
create_weave_networkattachmentdefinition &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Now setting role binding..."
deploy_cluster_role_binding &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Dropping weave iptables rule..."
weave_ip_tables_drop &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Making multus softlink..."
multus_softlink &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
check_ng_stack_state &>> $real_path/log/$start-log/cluster.log
echo "Creating cluster config file with name $CLUSTER_NAME.yaml"
make_cluster_config &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Creating nodegroup now, this can also take some time..."
create_node_group &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Creating IAM service accounts..."
create_iam_service_accounts &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Installing EKS add-ons..."
install_eks_add_on &>> $real_path/log/$start-log/cluster.log
echo -e "========================\n"
echo "Now configuring storage.."
echo -e "\n"
echo "Creating EFS (Elastic File System)..."
aws_create_file_system &>> $real_path/log/$start-log/cluster.log
echo "Now extracting subnet group ID..."
aws_get_subnet_id &>> $real_path/log/$start-log/cluster.log
echo "Subnet group ID: $subnet_id"
echo -e "\n"
aws_get_sg_id &>> $real_path/log/$start-log/cluster.log
echo -e "Done.\n"

echo "Creating EFS mount point"
aws_create_efs_mount_point &>> $real_path/log/$start-log/cluster.log
echo -e "Your EFS mountpoint DNS is: $efs_dns\n"
echo "Now creating EFS configmap"
create_cm_efs &>> $real_path/log/$start-log/cluster.log
echo -e "\n"
echo "Now creating EFS manifest"
create_efs_manifest &>> $real_path/log/$start-log/cluster.log

echo -e "========================\n"

echo "Creating EBS volume (Elastic Block Store)"
aws_create_ebs &>> $real_path/log/$start-log/cluster.log
echo "Now making persistent volume on EKS"
make_persistent_volume &>> $real_path/log/$start-log/cluster.log
echo "Done."
echo -e "========================\n"
echo "Setting up Redis..."
helm_redis_add_repo &>> $real_path/log/$start-log/cluster.log
echo "Helm Redis repo added"
echo "Now proceeding with Helm install"
helm_infra_install_redis &>> $real_path/log/$start-log/cluster.log
echo "Redis installed"
echo -e "========================\n"
helm_infra_install_influx_db &>> $real_path/log/$start-log/cluster.log
echo "InfluxDB installed"
echo -e "========================\n"
echo -e "We will setup the testground daemon now.\n"
echo "Creating configmap..."
tg_daemon_config_map &>> $real_path/log/$start-log/cluster.log
echo "Creating service account..."
tg_daemon_service_account &>> $real_path/log/$start-log/cluster.log
echo "Creating role binding..."
tg_daemon_role_binding &>> $real_path/log/$start-log/cluster.log
echo "Creating the testground service.."
tg_daemon_services &>> $real_path/log/$start-log/cluster.log
echo "Creating svc sync service..."
tg_daemon_svc_sync_service &>> $real_path/log/$start-log/cluster.log
echo "Creating sync service deployment..."
tg_daemon_sync_service &>> $real_path/log/$start-log/cluster.log
echo "Creating sidecar..."
tg_daemon_sidecar &>> $real_path/log/$start-log/cluster.log
echo "Creating testground daemon deployment..."
tg_daemon_deployment &>> $real_path/log/$start-log/cluster.log

echo -e "========================\n"
obtain_alb_address
echo "Checking with AWS if everything is ready..."
wait_for_alb_and_instances
echo -e "\n"
echo "Everything is up and running!"
echo -e "========================\n"
echo_env_toml
echo "Your cluster is ready to be used."
echo -e "\n"
log
echo "Log for this build can be found on this path $real_path/log/$start-$CLUSTER_NAME.tar.gz"