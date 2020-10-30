#!/bin/bash

sudo apt update
sudo apt install -y docker.io

sudo docker pull bitnami/redis:5.0.8-debian-10-r39
sudo docker pull bitnami/redis-exporter:1.5.2-debian-10-r27
sudo docker pull busybox:1.31.1
sudo docker pull busybox:1.31.1-glibc
sudo docker pull grafana/grafana:7.0.3
sudo docker pull influxdb:1.8-alpine
sudo docker pull iptestground/curl-ssl:0.0.1
sudo docker pull iptestground/goproxy:2.0.2
sudo docker pull iptestground/weave-kube:0.0.2-v2.7.0-63821434
sudo docker pull jettech/kube-webhook-certgen:v1.2.1
sudo docker pull jettech/kube-webhook-certgen:v1.3.0
sudo docker pull jimmidyson/configmap-reload:v0.3.0
sudo docker pull k8s.gcr.io/cluster-proportional-autoscaler-amd64:1.8.1
sudo docker pull k8s.gcr.io/coredns:1.6.7
sudo docker pull k8s.gcr.io/kube-apiserver:v1.18.10
sudo docker pull k8s.gcr.io/kube-controller-manager:v1.18.10
sudo docker pull k8s.gcr.io/kube-proxy:v1.18.10
sudo docker pull k8s.gcr.io/kube-scheduler:v1.18.10
sudo docker pull k8s.gcr.io/pause-amd64:3.2
sudo docker pull kiwigrid/k8s-sidecar:0.1.151
sudo docker pull kope/dns-controller:1.18.2
sudo docker pull kope/kops-controller:1.18.2
sudo docker pull kope/kube-apiserver-healthcheck:1.18.2
sudo docker pull kopeio/etcd-manager:3.0.20200531
sudo docker pull quay.io/coreos/flannel:v0.11.0-amd64
sudo docker pull quay.io/coreos/flannel:v0.13.0-amd64
sudo docker pull quay.io/coreos/prometheus-config-reloader:v0.38.1
sudo docker pull quay.io/coreos/prometheus-operator:v0.38.1
sudo docker pull quay.io/external_storage/efs-provisioner:v2.4.0
sudo docker pull quay.io/huawei-cni-genie/genie-admission-controller:1382
sudo docker pull quay.io/huawei-cni-genie/genie-plugin:1382
sudo docker pull quay.io/jetstack/cert-manager-webhook:v0.16.0
sudo docker pull quay.io/prometheus/node-exporter:v1.0.0
sudo docker pull quay.io/prometheus/prometheus:v2.18.2
sudo docker pull squareup/ghostunnel:v1.5.2

TEMPDIR=`mktemp -d`
pushd $TEMPDIR
wget https://kubeupv2.s3.amazonaws.com/kops/1.18.2/images/protokube.tar.gz
sudo docker load < protokube.tar.gz
popd

wget -O /tmp/kickstart-static64.sh https://my-netdata.io/kickstart-static64.sh
sh /tmp/kickstart-static64.sh --dont-wait --no-updates
