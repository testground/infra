#!/bin/bash
cd "$(dirname "$0")"
real_path=$(/bin/pwd)
parentdir=$(cd $real_path && cd ../ && pwd)
# install the prometheus operator
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
# add the prometheus config and install prometheus
kubectl apply -f $real_path/yaml/prometheus/prom-rbac.yml
kubectl apply -f $real_path/yaml/prometheus/prometheus.yml
# add weave monitoring dependencies
kubectl apply -f $real_path/yaml/prometheus/weave-svc.yml
kubectl apply -f $real_path/yaml/prometheus/weave-svc-monitor.yml
# install custom chart
cd $parentdir/kops/testground-infra/charts/testground-dashboards
helm install testground-infra .
# add and install grafana
cd $real_path/yaml/grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -f $real_path/yaml/grafana/Values.yaml