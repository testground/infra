#!/bin/bash
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
  cluseter_created = 1
  create_cluster
  echo "========================"
  echo ""
fi

if [[ "$CNI_COMBINATION" == "calico_weave" ]]
 then
   echo "Calico - weave combination is selected."
   echo "Removing aws_node DS"
   remove_aws_node_ds
   echo "Adding tigera operator"
   add_tigera_operator
   echo "Deploying tigera operator"
   deploy_tigera_operato
   echo "========================"
else
  echo "Invalid selecton in .env"  >> ./log/$start-log/erorr.log
  echo "CNI_COMBINATION cant be $CNI_COMBINATION" >> ./log/$start-log/erorr.log
  echo "Option are calico_weave or aws_vpc_cni_weave"
  exit 1
fi

echo "Detecting if multus-cni repo exists...."
sleep 1
echo ""
if [ -d "./multus-cni" ] 
then
    echo "/usr/bin/printf "[\xE2\x9C\x94] Multus-CNI\n"" >> ./log/$start-log/deploy_multus_ds.log
    echo "Now deploying multus-cni DS"
    deploy_multus_ds
else
    echo "[X] Multus-CNI" >> ./log/$start-log/deploy_multus_ds.log
    echo "Now cloning Multus repository..."
    clone_multus
    echo "Now deploying multus-cni DS"
    deploy_multus_ds
fi