#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

check_yq() {
    if [[ -z $(which yq) ]]
    then
        echo "yq is not installed, you must install it first."
        exit 1;
    fi
}

check_sha256sum() {
    if [[ -z $(which sha256sum) ]]
    then
        echo "sha256sum is not installed, you must install it first."
        exit 1;
    fi
}

update_deployment_config_hash() {
    shasum=$(kubectl get cm/$3 | sha256sum | cut -d " " -f1)
    yq -i e ".spec.template.metadata.annotations.$2 |=\"$shasum\"" $1
}

trap 'err_report $LINENO' ERR

check_yq
check_sha256sum
kubectl delete deployment testground-daemon || true
kubectl delete service testground-daemon || true
kubectl apply -f config-map-env-toml.yml
update_deployment_config_hash deployment.yml configHash env-toml-cfg
kubectl apply -f service-account.yml
kubectl apply -f role-binding.yml
kubectl apply -f deployment.yml -f service.yml
