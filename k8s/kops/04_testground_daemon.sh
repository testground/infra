#!/bin/bash

set -o errexit
set -o pipefail
set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

START_TIME=`date +%s`

CLUSTER_SPEC_TEMPLATE=$1

my_dir="$(dirname "$0")"
source "$my_dir/install-playbook/validation.sh"

echo "Installing Testground daemon..."
echo
kubectl apply -f ./testground-daemon/config-map-env-toml.yml
kubectl apply -f ./testground-daemon/service-account.yml
kubectl apply -f ./testground-daemon/role-binding.yml
kubectl apply -f ./testground-daemon/deployment.yml -f ./testground-daemon/service.yml

echo "Testground daemon is ready"
echo

END_TIME=`date +%s`
echo "Execution time was `expr $END_TIME - $START_TIME` seconds"

