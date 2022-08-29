#!/bin/bash
set -e #lets make sure that exit code 1 drops the script
start = $(date +"%Y-%m-%d-%T")
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

export $(grep -v '^#' .env | xargs) #exporting .env vars

#Lets do sanity check

if [[ "$CLUSTER_NAME" == "default" ]]
 then
   echo "Your cluster name cant be "default" " 
   echo "Please edit .env which is located in the same directory as this script"
else
  echo "Creating cluster with name: $CLUSTER_NAME "
  echo "Please note, this can take up to 20 minutes to complete." 
  cluster_created = 1
  create_cluster
  echo "========================"
  echo ""
fi

echo "Detecting if multus-cni repo exists...."
sleep 1
echo ""
if [ -d "./multus-cni" ] 
then
    echo "/usr/bin/printf "[\xE2\x9C\x94] Multus-CNI\n"" >> ./log/$start-log/deploy_multus_ds.log
    echo "Now deploying multus-cni DS"
    deploy_multus_ds
    echo "========================"
else
    echo "[X] Multus-CNI" >> ./log/$start-log/deploy_multus_ds.log
    echo "Now cloning Multus repository..."
    clone_multus
    echo "Now deploying multus-cni DS"
    deploy_multus_ds
     echo "========================"
fi

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
  echo "Deploying multusds and selected cni failed" >> ./log/$start-log/erorr.log
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