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
                  EKS uninstall script 


EOF
echo "Please seleect the cluster you want to remove"
unset options i
while IFS= read -r -d $'\0' f; do
  options[i++]="$f"
done < <(find $real_path/.cluster/ -maxdepth 1 -type f -name "*.cs" -print0 )

select opt in "${options[@]}" "Stop the uninstall script"; do
  case $opt in
    *.cs)
      echo "You have selected to remove: $opt "
      source $opt
      cleanup
      ;;
    "Stop the script")
      echo "You chose to stop"
      break
      ;;
    *)
      echo "This is not a number"
      ;;
  esac
done