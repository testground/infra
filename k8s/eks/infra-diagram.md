This page shows how the infrastructure looks like after the script finishes, along with some other information.

### Cluster and nodegroups

The script uses `eksctl` as the main tool to create the cluster and two nodegroups by default. <br />
The nodegroups are called `ng-1-infra` and `ng-2-plan`.

![cluster-ngs](https://user-images.githubusercontent.com/43587123/194022047-93a52ab9-8b06-4946-a945-5ce33e0c2a24.PNG)

### Pod scheduling

Per design, some pods need to be scheduled on certain nodes. We achieve this using node labels.
When creating the nodegroup, `eksctl` adds these to the nodegroups:

```
    labels:
      "testground.node.role.infra": "true"
```
and:
```
    labels:
      "testground.node.role.plan": "true"
```

Then, the same label is added as a `nodeSelector` property for the following pods:

![pod-scheduling](https://user-images.githubusercontent.com/43587123/194022175-b2c07817-4d6b-45da-b8ab-1c38c1b70484.PNG)

### Communication with the testground-daemon

Once all components have been deployed to the cluster, the users should be able to schedule runs.

The `testground-daemon` pod is fronted by a kubernetes service that is deployed as `type: LoadBalancer`. This means that an AWS Classic Load Balancer is created,
which enables us to communicate with the `testground-daemon` service, and through it, with the `testground-daemon` itself.

Information on the exact LB hostname is shown to the user at the end of the script run, in the form of the `.env.toml` file.

![daemon-comm](https://user-images.githubusercontent.com/43587123/194022117-463e7db3-7d3a-4d1d-ba53-d11f9c3893c4.PNG)

