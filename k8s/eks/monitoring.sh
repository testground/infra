#!/usr/bin/env bash
# This script will install the following:
# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
#
# It can be uninstalled by running:
# helm install tg-monitoring prometheus-community/kube-prometheus-stack

echo -e "Now obtaining the helm charts and installing the monitoring stack. This might take a few minutes.\n"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install tg-monitoring prometheus-community/kube-prometheus-stack

echo -e "========================"
echo -e "You can obtain the admin password for grafana by running the following command:\n"
echo -e "kubectl get secret --namespace default tg-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo\n"
echo -e "You may then run the following in order to obtain the grafana pod name:\n"
echo -e 'export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=tg-monitoring" -o jsonpath="{.items[0].metadata.name}")'
echo -e "You may now run the following in order to port-forward and access the grafana dashboard from your laptop by opening 'localhost:3000' in your browser:\n"
echo -e 'kubectl --namespace default port-forward $POD_NAME 3000'
echo -e "========================\n"