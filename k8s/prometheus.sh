#!/bin/bash

set -o errexit
set -o pipefail

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

echo "Installing Prometheus"

pushd prometheus
helm install grafana stable/prometheus -f values.yaml --namespace monitoring

popd

echo "Installing Grafana"
pushd grafana

kubectl apply -f configmap.yaml --namespace monitoring
helm install grafana stable/grafana -f values.yaml --namespace monitoring

popd
