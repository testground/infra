#!/bin/bash
set -e #lets make sure that exit code 1 drops the script
start=$(date +"%Y-%m-%d-%T")
source ./bash/functions.sh
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

#Lets do sanity check

if [[ "$CLUSTER_NAME" == "default" ]]
 then
   echo "Your cluster name cant be "default" " 
   echo "Please edit .env which is located in the same directory as this script"
   exit 1
else
  echo "Creating cluster with name: $CLUSTER_NAME "
  echo "Please note, this can take up to 20 minutes to complete." 
  create_cluster
  cluster_created=1
  echo "========================"
  echo ""
fi

echo "Now deploying multus-cni DS"
deploy_multus_ds
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
   echo "Calico - weave combination is selected."
   echo "Removing aws_node DS"
   remove_aws_node_ds
   echo "Adding tigera operator"
   add_tigera_operator
   echo "Deploying tigera operator"
   deploy_tigera_operator
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
apply_weave
create_weave
echo "========================"

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
  echo "Deploying calico and multus DS"
  deploy_vpc_weave_multusds
  deploy_vpc_multus_cm_calico
  echo "========================"
else
  echo "Deploying multus DS and selected cni failed" >> ./log/$start-log/erorr.log
  echo "exiting" >> ./log/$start-log/erorr.log
  echo "========================"
  exit 1
fi

echo "Now setging role binding..."
deploy_cluster_role_binding
echo "========================"

echo "Droping weave ip table rule..."
weave_ip_tables_drop
echo "========================"

echo "Making multus softlink..."
multus_soflink
echo "========================"

echo "Creating cluster config file with name $CLUSTER_NAME.yaml"
make_cluster_config
echo "========================"

echo "Creating cluster now..."
create_cluster
echo "========================"

echo "Creating and mounting efs"
jq_check
aws_create_file_system
aws_create_efs_sg
aws_get_subent_id
aws_get_subent_cidr_block
aws_efs_sg_rule_add
aws_create_efs_mount_point
echo "========================"

echo "Creating ebs"
aws_create_ebs
make_persistant_volume
echo "========================"

echo "Seting up redis..."
helm_redis_add_repo
helm_infra_install_redis

echo "We will setup the test-ground daemon now."

tg_daemon_config_map
tg_daemon_service_account
tg_daemon_role_binding
tg_daemon_services
tg_daemon_svc_sync_service
tg_daemon_sync_service
tg_daemon_sidecar
tg_daemon_deployment

echo "========================"

echo "Your cluster is ready to be used"