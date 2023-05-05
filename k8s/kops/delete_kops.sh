#!/bin/bash

set -o errexit
set -o pipefail
set -x
set -e

TF_RESOURCES="../../terraform/kops-resources/"

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

# =======================================================
echo "Create EFS resources & storageclasses..."
cd ${TF_RESOURCES}
terraform destroy -auto-approve &&\
cd -
pwd
# =======================================================
kops delete cluster $CLUSTER_NAME --yes
