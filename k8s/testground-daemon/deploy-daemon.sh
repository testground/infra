#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

kubectl delete deployment testground-daemon || true
kubectl delete service testground-daemon || true
kubectl apply -f config-map-env-toml.yml
kubectl apply -f service-account.yml
kubectl apply -f role-binding.yml
kubectl apply -f deployment.yml -f service.yml
