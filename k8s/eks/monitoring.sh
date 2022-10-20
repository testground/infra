#!/bin/bash
# This script will install the following:
# - prometheus (operator + resource + serviceaccount with cluster roles)
# - grafana
# - 'ServiceMonitor' resource to gain insight into weave (secondary network used for testground)
# - Custom testground grafana dashboards

cd "$(dirname "$0")"
real_path=$(/bin/pwd)
parentdir=$(cd $real_path && cd ../ && pwd)

# Install the prometheus operator
echo -e "\n"
echo "========================"
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
echo -e "\n"
echo "========================"
# Add the prometheus config and install prometheus
kubectl apply -f $real_path/yaml/prometheus/prom-rbac.yml
kubectl apply -f $real_path/yaml/prometheus/prometheus.yml
# Add weave monitoring dependencies
kubectl apply -f $real_path/yaml/prometheus/weave-svc.yml
kubectl apply -f $real_path/yaml/prometheus/weave-svc-monitor.yml
# Install the custom chart for testground-dashboards
cd $parentdir/kops/testground-infra/charts/testground-dashboards
echo -e "\n"
echo "========================"
helm install testground-infra .
# Add and install grafana
cd $real_path/yaml/grafana
echo -e "\n"
echo "========================"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -f $real_path/yaml/grafana/Values.yml