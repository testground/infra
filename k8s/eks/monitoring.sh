#!/bin/bash
cd "$(dirname "$0")"
real_path=$(/bin/pwd)
parentdir=$(cd $real_path && cd ../ && pwd)
# install the prometheus operator
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
# add the prometheus config and install prometheus
kubectl apply -f $real_path/prometheus/prom_rbac.yml
kubectl apply -f $real_path/prometheus/prometheus.yml
# add weave monitoring dependencies
kubectl apply -f $real_path/prometheus/weave-svc.yml
kubectl apply -f $real_path/prometheus/weave-svc-monitor.yml
# install custom chart
cd $parentdir/kops/testground-infra/charts/testground-dashboards
helm install .
# add and install grafana
cd $real_path/grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana