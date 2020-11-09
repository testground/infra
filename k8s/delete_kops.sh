#!/bin/bash

set -o errexit
set -o pipefail
set -x
set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

kops delete cluster $CLUSTER_NAME --yes
