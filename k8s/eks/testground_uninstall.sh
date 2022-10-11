#!/bin/bash
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
                  EKS uninstall script 


EOF
echo ""
echo "========================"
echo "PLEASE NOTE:"
echo "Running resources on AWS costs money."
echo "This script should delete the following resources that have been created with the 'testground_install.sh' script:"
echo "  - 3 Cloudformation stacks created by eksctl - EKS cluster and 2 Nodegroups"
echo "(Note: if you created more than the default 2 nodegroups, then there will be more stacks)"
echo "  - EBS (Elastic Block Storage) volume in the selected Availability Zone"
echo "  - EFS (Elastic File System) in the selected AWS Region, along with a EFS mount target for the selected Availability Zone"
echo "Once the script finishes, you will be able to verify everything through the AWS console."
echo "========================"
echo ""
echo "Please select the cluster you want to remove"

unset options i
i=0
while IFS= read -r -d $'\0' f; do
  options[i++]="$f"
done < <(find $real_path/.cluster -maxdepth 1 -type f -name "*.cs" -print0 )

select opt in "${options[@]}" "Stop the uninstall script"; do
  case $opt in
    *.cs)
      echo "You have selected to remove: $opt "
      source $opt
      cleanup
      echo ""
      break
      ;;
    "Stop the uninstall script")
      echo "You chose to stop, exiting now."
      break
      ;;
    *)
      echo "Wrong selection. Please try again!"
      ;;
  esac
done