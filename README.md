# Testground infrastructure

This repo contains scripts for setting up a Kubernetes cluster for [Testground](https://testground.ipfs.team).

Using the `cluster:k8s` runner of Testground enables you to test distributed/p2p systems at large scales. Testing at large scale is an essential component of developing rock-solid distributed software.

The `cluster:k8s` Testground runner is capable of launching test workloads comprising 10k+ instances, and we aim to reach 100k at some point.

The [IPFS](https://ipfs.io/) and [libp2p](https://libp2p.io/) projects have used these scripts and playbooks to deploy large-scale test infrastructure. By crafting test scenarios that exercise components at such scale, we have been able to run simulations, carry out attacks, perform benchmarks, and execute all kinds of test to validate correctness at scale.

## Quick start

We are using kops to create a cluster rather than a hosted kubernetes service. Doing it this way enables us to tune kernel parameters and make customizations that have proven to be important.

There are a couple of dependencies required to make the `cluster:k8s` runner work.

### required software
  * an AWS account with API access
  * helm v3+ [link](https://helm.sh/)
  * kops v1.17.0+ [link](https://github.com/kubernetes/kops/releases)
  * terraform v0.12+ [link](https://www.terraform.io/)

### environment variables
Set up environment variables before starting the cluster
  * AWS_PROFILE      (if you have multiple AWS accounts)
  * NAME             (cluster name)
  * PUBKEY           (SSH key for testground workers)
  * ZONE             (availability zone i.e. us-west-2a)
  * AWS_REGION       (where is your cluster. i.e. us-west-2)
  * KOPS_STATE_STORE (s3 bucket for kops)
  * WORKER_NODES     (size of your kubernetes cluster)

### Create the cluster
This will take about 15 minutes to complete.
Once you run this, take some time to walk the dog, clean up around the office, or go get yourself some coffee! When you return, your shiny new kubernetes cluster will be ready to run testground plans.

```
k8s/install.sh k8s/cluster.yaml
```

## Documentation
Additional information about this runner and more can be found on [testground gitbook](https://app.gitbook.com/@protocol-labs/s/testground/)

## Contribute

Our work is never finished. If you see anything we can do better, file an issue or open a PR!

## License

Dual-licensed: [MIT](./LICENSE-MIT), [Apache Software License v2](./LICENSE-APACHE), by way of the [Permissive License Stack](https://protocol.ai/blog/announcing-the-permissive-license-stack/).
