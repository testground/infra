#!/bin/bash

set -o errexit
set -o pipefail
set -x
set -e

# =======================================================
TF_RESOURCES="../../terraform/kops-resources/"
# =======================================================

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

# =======================================================

# Load values form the file
if [ -f ./values.sh ];then
    source ./values.sh
else
    echo "[ERROR] Please, you need to fill the values in the script [values.sh]"
    exit 1
fi

# =======================================================
echo "Create EFS resources & storageclasses..."
cd ${TF_RESOURCES}
terraform destroy -auto-approve &&\
cd -
pwd
# =======================================================
kops delete cluster $CLUSTER_NAME --yes
