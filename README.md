# Testground infrastructure




## Issues
Please report any issues you may want to submit in the testground/testground repo.

## Background

This repo contains scripts for setting up a Kubernetes cluster for [Testground](http://testground.ipfs.team).

Using the `cluster:k8s` runner of Testground enables you to test distributed/p2p systems at scale.

The `cluster:k8s` Testground runner is capable of launching test workloads comprising 10k+ instances, and we aim to reach 100k at some point.

The [IPFS](https://ipfs.io/) and [libp2p](https://libp2p.io/) projects have used these scripts and playbooks to deploy large-scale test infrastructure. By crafting test scenarios that exercise components at such scale, we have been able to run simulations, carry out attacks, perform benchmarks, and execute all kinds of tests to validate correctness and performance.

## Introduction

Kubernetes Operations (`kops`) is a tool which helps to create, destroy, upgrade and maintain production-grade Kubernetes clusters from the command line. We use it to create a Kubernetes cluster on AWS.

We use CoreOS Flannel for networking on Kubernetes - for the default Kubernetes network, which in Testground terms is called the `control` network.

We use Weave for the `data` plane on Testground - a secondary overlay network that we attach containers to on-demand.

`kops` uses 100.96.0.0/11 for pod CIDR range, so this is what we use for the `control` network.

We configure Weave to use 16.0.0.0/4 as CIDR (we want to test `libp2p` nodes with IPs in public ranges), so this is the CIDR for the Testground `data` network. The `sidecar` is responsible for setting up the `data` network for every testplan instance.

In order to have two different networks attached to pods in Kubernetes, we run the [CNI-Genie CNI](https://github.com/cni-genie/CNI-Genie).

More information on the Testground Networking requirements can be found [here](https://github.com/testground/testground/blob/master/docs/NETWORKING.md).


## Requirements

1. An AWS account with API access
2. [kops](https://github.com/kubernetes/kops/releases) >= 1.17.0
3. [terraform](https://terraform.io) >= 0.12.21
4. [AWS CLI](https://aws.amazon.com/cli)
5. [helm](https://github.com/helm/helm) >= 3.0

## Set up cloud credentials, cluster specification and repositories for dependencies

1. [Generate your AWS IAM credentials](https://console.aws.amazon.com/iam/home#/security_credentials).

    * [Configure the aws-cli tool with your credentials](https://docs.aws.amazon.com/cli/).
    * Create a `.env.toml` file (copying over the [`env-example.toml`](https://github.com/ipfs/testground/blob/master/env-example.toml) at the root of this repo as a template), and add your region to the `[aws]` section.

2. For the Testground team: Download shared key for `kops`. The Testground team uses a shared key, so that everyone on the team can log into any ephemeral cluster and have full access.

```sh
$ aws s3 cp s3://kops-shared-key-bucket/testground_rsa ~/.ssh/
$ aws s3 cp s3://kops-shared-key-bucket/testground_rsa.pub ~/.ssh/
$ chmod 700 ~/.ssh/testground_rsa
```

Or generate your own key, for example

```sh
$ ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

3. Create a bucket for `kops` state. This is similar to Terraform state bucket.

```sh
$ aws s3api create-bucket \
      --bucket <bucket_name> \
      --region <region> --create-bucket-configuration LocationConstraint=<region>
```

Where:

* `<bucket_name>` is a unique AWS account-wide unique bucket name to store this cluster's kops state, e.g. `kops-backend-bucket-<your_username>`.
* `<region>` is an AWS region like `eu-central-1` or `us-west-2`.

4. Pick:

- a cluster name,
- set AWS region
- set AWS availability zone A (not region; for example `us-west-2a` [availability zone]) - used for master node and worker nodes
- set AWS availability zone B (not region; for example `us-west-2b` [availability zone]) - used for more worker nodes
- set `kops` state store bucket
- set number of worker nodes
- set location for cluster spec to be generated
- set location of your cluster SSH public key
- set credentials and locations for `outputs` S3 bucket

You might want to add them to your `rc` file (`.zshrc`, `.bashrc`, etc.), or to an `.env.sh` file that you source.

In addition to the initial cluster setup, these variables should be accessible to the daemon. If these variables are
manually set or you source them manually, you should make sure to do so before starting the Testground daemon.

```sh
# `NAME` needs to be a subdomain of an existing Route53 domain name.
# The Testground team uses `.testground.ipfs.team`, which is already set up for our Testground AWS account.
# Alternatively you could use `name.k8s.local` and use Gossip DNS.
export NAME=<desired kubernetes cluster name (cluster name must be a fully-qualified DNS name (e.g. mycluster.k8s.local or mycluster.testground.ipfs.team)>
export KOPS_STATE_STORE=s3://<kops state s3 bucket>
export AWS_REGION=<aws region, for example eu-central-1>
export ZONE_A=<aws availability zone, for example eu-central-1a>
export ZONE_B=<aws availability zone, for example eu-central-1b>
export WORKER_NODES=4
export PUBKEY=$HOME/.ssh/testground_rsa.pub
export TEAM=<optional - your team name ; used for cost allocation purposes>
export PROJECT=<optional - your project name ; used for cost allocation purposes>
```

5. Set up Helm and add the `stable` Helm Charts repository

If you haven't, [install helm now](https://helm.sh/docs/intro/install/).

```sh
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo update
```

## Create the Kubernetes cluster

This will take about 10-15 minutes to complete.

Once you run this command, take some time to walk the dog, clean up around the office, or go get yourself some coffee! When you return, your shiny new kubernetes cluster will be ready to run testground plans.

To create a monitored cluster in the region specified in `$ZONE` with
`$WORKER_NODES` number of workers:

```sh
$ ./k8s/install.sh ./k8s/cluster.yaml
```

## Destroy the cluster when you're done working on it

Do not forget to delete the cluster once you are done running test plans.

```sh
$ ./k8s/delete.sh
```

## Resizing the cluster

1. Edit the cluster state and change number of nodes.

```sh
$ kops edit ig nodes
```

2. Apply the new configuration

```sh
$ kops update cluster $NAME --yes
```

3. Wait for nodes to come up and for DaemonSets to be Running on all new nodes

```sh
$ watch 'kubectl get pods'
```

## Testground observability

1. Access to Grafana (initial credentials are `username: admin` ; `password: testground`):

```sh
$ kubectl port-forward service/testground-infra-grafana 3000:80
```

## Cleanup after Testground and other useful commands

Testground is still in very early stage of development. It is possible that it crashes, or doesn't properly clean-up after a testplan run. Here are a few commands that could be helpful for you to inspect the state of your Kubernetes cluster and clean up after Testground.

1. Delete all pods that have the `testground.plan=dht` label (in case you used the `--run-cfg keep_service=true` setting on Testground.

```sh
$ kubectl delete pods -l testground.plan=dht --grace-period=0 --force
```

2. Restart the `sidecar` daemon which manages networks for all testplans

```sh
$ kubectl delete pods -l name=testground-sidecar --grace-period=0 --force
```

3. Review all running pods

```sh
$ kubectl get pods -o wide
```

4. Get logs from a given pod

```sh
$ kubectl logs <pod-id, e.g. tg-dht-c95b5>
```

5. Check on the monitoring infrastructure (it runs in the monitoring namespace)

```sh
$ kubectl get pods --namespace monitoring
```

6. Get access to the Redis shell

```sh
$ kubectl port-forward svc/testground-infra-redis-master 6379:6379 &
$ redis-cli -h localhost -p 6379
```

## Use a Kubernetes context for another cluster

`kops` lets you download the entire Kubernetes context config.

If you want to let other people on your team connect to your Kubernetes cluster, you need to give them the information.

```sh
$ kops export kubecfg --state $KOPS_STATE_STORE --name=$NAME
```

## Documentation
Additional information about this runner and more can be found on the [Testground gitbook](https://app.gitbook.com/@protocol-labs/s/testground/)

## Contribute

Our work is never finished. If you see anything we can do better, file an issue on [github.com/testground/testground](https://github.com/testground/testground) repo or open a PR!

## License

Dual-licensed: [MIT](./LICENSE-MIT), [Apache Software License v2](./LICENSE-APACHE), by way of the [Permissive License Stack](https://protocol.ai/blog/announcing-the-permissive-license-stack/).
