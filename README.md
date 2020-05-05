# Testground infrastructure

This repo contains scripts for setting up a Kubernetes cluster for [Testground](https://docs.testground.ai).

## Using these scripts

Documentation and step-by-step guides on how to use these infrastructure playbooks, the `cluster:k8s` runner, and more, can be found on the [Testground documentation website](http://docs.testground.ai/). 

## Background

The `cluster:k8s` runner of Testground enables you to test distributed/p2p systems at scale. It is capable of launching test workloads comprising 10k+ instances, and we aim to reach 100k at some point.

The [IPFS](https://ipfs.io/) and [libp2p](https://libp2p.io/) projects have used these scripts and playbooks to deploy large-scale test infrastructure. By crafting test scenarios that exercise components at such scale, we have been able to run simulations, carry out attacks, perform benchmarks, and execute all kinds of tests to validate correctness and performance.

## Contribute

Our work is never finished. If you see anything we can do better, file an issue on [github.com/testground/testground](https://github.com/testground/testground) repo or open a PR!

## License

Dual-licensed: [MIT](./LICENSE-MIT), [Apache Software License v2](./LICENSE-APACHE), by way of the [Permissive License Stack](https://protocol.ai/blog/announcing-the-permissive-license-stack/).
