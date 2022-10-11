# This dockerfile builds a container containing
#  all the testground_*.sh scripts dependencies
#
# To build:
#  docker build --platform amd64 --tag testground-on-eks:latest - < Dockerfile
#
# To run (assumes you have AWS credentials in ~/.aws/credentials):
# docker run --rm -it -v ~/.aws:/root/.aws -v $(pwd):/root/eks testground-on-eks:latest

ARG AMAZONLINUX_TAG=2.0.20220912.1
ARG HELM_VERSION=3.8.2
ARG KUBECTL_VERSION=1.22.0
ARG AWSCLIV2_VERSION=2.8.2
ARG EKSCTL_VERSION=0.114.0
ARG JQ_VERSION=1.6

FROM amazonlinux:${AMAZONLINUX_TAG} AS base
RUN yum update -y && yum install -y \
    tar \
    gzip \
    unzip \
    && yum clean all

FROM base AS helm
ARG HELM_VERSION
RUN curl -fsSLO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
RUN tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
RUN mv linux-amd64/helm /usr/local/bin/helm

FROM base AS kubectl
ARG KUBECTL_VERSION
RUN curl -fsSLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl
RUN curl -fsSLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
RUN echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
RUN chmod +x kubectl
RUN mv kubectl /usr/local/bin/kubectl

FROM base as awscliv2
ARG AWSCLIV2_VERSION
RUN curl -fsSLO https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLIV2_VERSION}.zip
RUN unzip awscli-exe-linux-x86_64-${AWSCLIV2_VERSION}.zip
RUN mv aws /tmp/aws

FROM base as eksctl
ARG EKSCTL_VERSION
RUN curl -fsSLO https://github.com/weaveworks/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz
RUN tar -zxvf eksctl_Linux_amd64.tar.gz
RUN mv eksctl /usr/local/bin/eksctl

FROM base as jq
ARG JQ_VERSION
RUN curl -LO https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
RUN chmod +x jq-linux64
RUN mv jq-linux64 /usr/local/bin/jq

FROM amazonlinux:${AMAZONLINUX_TAG}
RUN yum update -y && yum install -y \
    tar \
    gzip \
    gettext \
    && yum clean all
COPY --from=helm /usr/local/bin/helm /usr/local/bin/helm
COPY --from=kubectl /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=awscliv2 /tmp/aws /tmp/aws
RUN /tmp/aws/install && rm -rf /tmp/aws
COPY --from=eksctl /usr/local/bin/eksctl /usr/local/bin/eksctl
COPY --from=jq /usr/local/bin/jq /usr/local/bin/jq

WORKDIR /root
