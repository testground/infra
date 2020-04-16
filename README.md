# Testground infrastructure

This repo contains scripts for setting up a Kubernetes cluster for [Testground](https://testground.ipfs.team).

Using the `cluster:k8s` runner of Testground enables you to test distributed/p2p systems at large scales. Testing at large scale is an essential component of developing rock-solid distributed software.

The `cluster:k8s` Testground runner is capable of launching test workloads comprising 10k+ instances, and we aim to reach 100k at some point.

The [IPFS](https://ipfs.io/) and [libp2p](https://libp2p.io/) projects have used these scripts and playbooks to deploy large-scale test infrastructure. By crafting test scenarios that exercise components at such scale, we have been able to run simulations, carry out attacks, perform benchmarks, and execute all kinds of test to validate correctness at scale.

## Quick start

<@coryschwartz>

## Documentation

<@coryschwartz: point to the relevant sections in GitBook>

## Contribute

Our work is never finished. If you see anything we can do better, file an issue or open a PR!

## License

Dual-licensed: [MIT](./LICENSE-MIT), [Apache Software License v2](./LICENSE-APACHE), by way of the [Permissive License Stack](https://protocol.ai/blog/announcing-the-permissive-license-stack/).
