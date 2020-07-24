#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

while :
do
  testground healthcheck --runner cluster:k8s
	sleep 120
done
