# IPFS Testground infrastructure

This repo contains scripts for setting up a kubernetes cluster for [ipfs testground](https://testground.ipfs.team)

Using the kubernetes cluster runner on IPFS testground enables you to test p2p workloads at high scaleu. Testing at high volume is a pivotal component of developing rock solid distributed software. Using the kuberentes runner, testground can test workloads with 10k+ instances. While this is magnitudes smaller than the interplanetary-scale IPFS network, testing at this level has enabled us to find issues that would have been undetectable on smaller tests.


Our work is never finished. If you see anything we can do better, file an issue or open a PR!


## Team

The current Testground Team is composed of:

- @raulk - Tech Lead, Lead Software Engineer
- @nonsense - Software Engineer, Testground as a Service / Infrastructure Lead
- @Robmat05 - [Technical Project Manager (TPM)](https://github.com/ipfs/team-mgmt/blob/master/TEAMS_ROLES_STRUCTURES.md#working-group-technical-project-manager-tpm)
- @coryschwartz - Software Engineer
- you! Yes, you can contribute as well, however, do understand that this is a brand new and fast moving project and so contributing might require extra time to onboard


## License

Dual-licensed: [MIT](./LICENSE-MIT), [Apache Software License v2](./LICENSE-APACHE), by way of the [Permissive License Stack](https://protocol.ai/blog/announcing-the-permissive-license-stack/).
