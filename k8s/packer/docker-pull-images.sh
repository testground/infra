#!/bin/bash
sudo docker pull governmentpaas/curl-ssl:latest
sudo docker pull grafana/grafana:7.0.3
sudo docker pull busybox:latest
sudo docker pull kope/kops-controller:1.18.0-beta.1
sudo docker pull kope/dns-controller:1.18.0-beta.1
sudo docker pull kope/kube-apiserver-healthcheck:1.18.0-beta.1
sudo docker pull quay.io/prometheus/node-exporter:v1.0.0
sudo docker pull k8s.gcr.io/kube-proxy:v1.18.3
sudo docker pull k8s.gcr.io/kube-apiserver:v1.18.3
sudo docker pull k8s.gcr.io/kube-scheduler:v1.18.3
sudo docker pull k8s.gcr.io/kube-controller-manager:v1.18.3
sudo docker pull quay.io/prometheus/prometheus:v2.18.1
sudo docker pull kiwigrid/k8s-sidecar:0.1.151
sudo docker pull influxdb:1.8-alpine
sudo docker pull bitnami/redis:5.0.8-debian-10-r39
sudo docker pull docker.io/bitnami/redis-exporter:1.5.2-debian-10-r27
sudo docker pull nonsens3/weave-kube:latest
sudo docker pull k8s.gcr.io/coredns:1.6.7
sudo docker pull quay.io/external_storage/efs-provisioner:latest
sudo docker pull quay.io/huawei-cni-genie/genie-admission-controller:latest
sudo docker pull quay.io/huawei-cni-genie/genie-plugin:latest
sudo docker pull quay.io/coreos/flannel:v0.11.0-amd64
sudo docker pull k8s.gcr.io/cluster-proportional-autoscaler-amd64:1.4.0
sudo docker pull kopeio/etcd-manager:3.0.20200531
sudo docker pull k8s.gcr.io/pause-amd64:3.2

TEMPDIR=`mktemp -d`
pushd $TEMPDIR
wget https://kubeupv2.s3.amazonaws.com/kops/1.8.1/images/protokube.tar.gz
sudo docker load < protokube.tar.gz
popd
