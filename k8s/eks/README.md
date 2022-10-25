This guide will help you setup an EKS (Elastic Kubernetes Service) cluster, and run testground plans on it.

## Requirements

It is assumed that you already have the following:

- A bastion host on AWS, or a laptop with AWS credentials which will be used to run the installation script, interact with the cluster, and run testground plans
- The laptop or bastion host has the following software installed:

**Note: the software and installation guides have been tested on amazon linux. Please verify which OS are you using and follow the official guides accordingly.
Links have been included for each software requirement. Listed guides are for example purposes only.**

You can find the official AWS guide for setting up a bastion host here:

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/get-set-up-for-amazon-ec2.html

**TODO: As manual setup is error-prone, and likely will get outdated pretty quickly. We need to look into creating a custom AMI.**

**1. docker**

Official installation guide:

https://docs.docker.com/engine/install/ubuntu/

Installation on amazon linux:

```
sudo yum install docker -y
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker ec2-user
newgrp docker
```

**2. helm**

Official installation guide:

https://helm.sh/docs/intro/install/


Latest:
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Specific version used at the time of writing this guide (v3.8.2):

https://github.com/helm/helm/releases/tag/v3.8.2

```
wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz
tar -zxvf helm-v3.8.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
helm version
```

**3. kubectl**

Official installation guide:

https://kubernetes.io/docs/tasks/tools/

Latest version:

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

Specific version used at the time of writing this guide (v1.22):

```
curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**4. AWS CLI (v2) with AWS credentials**

**NOTE: You decide which AWS region you want to use, there are no limitations when it comes to this script. A list can be found here:**

https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html

First install the aws cli v2 (note that v1 is already installed if using amazon linux, so you will first need to remove the v1 and install v2):

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install

Then configure the credentials:

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

**5. eksctl**

Official installation guide:

https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html


Specific version used at the time of writing this guide (v0.112.0):

```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.112.0/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

**6. jq**

jq is a lightweight and flexible command-line JSON processor, used within the setup script.

Official installation guide:

https://stedolan.github.io/jq/download/


## Step by step installation guide

1. Pull the infra repo from here:

git clone https://github.com/testground/infra.git

and the testground repo from here:

git clone https://github.com/testground/testground.git

2. You need to generate and populate the `.env` file with the needed parameters before creating the cluster. It needs to be located in `infra/k8s/eks/`

You may use the existing `.env.example` as a template to create your own `.env` file.

The variables are divided into two main groups - `REQUIRED TO BE CHANGED` and `OPTIONAL TO BE CHANGED/ CAN BE LEFT WITH DEFAULTS`.

The `REQUIRED` variables need to be populated by the user - `CLUSTER_NAME` (unique cluster name, so your EKS cluster will be called `eks-$CLUSTER_NAME-cluster)`.

The `OPTIONAL/DEFAULTS` are safe to remain unchanged, but you are free to modify them to suit your needs. Please refer to the `.env` file for more information about each parameter.

3. Run the installation script `./testground_install.sh`; note that it requires the `.env` file to be populated in order to run properly. In case of any missing variables, the setup will fail and you will get an error message

The script explained in short:

- Takes approx. 15-20 minutes to provision a cluster with 2 worker nodegroups, along with all other necessary resources and cluster workloads
- All installation steps have been divided into functions, located in the `eks/bash/functions.sh` script
- The script calls functions one by one
- Output of every step is logged into a master log file that can be retrieved and reviewed, or even tailed in real time from a different terminal window while the script is running
- The `functions.sh` file relies on the content of `eks/yaml` - all cluster resources are located inside this folder
- If you need to scale the worker nodegroups on setup, you are able to edit the `.env` file parameters - `DESIRED_CAPACITY_INFRA` and `DESIRED_CAPACITY_PLAN`
- You are also able to change the worker node instance type - `INSTANCE_TYPE_INFRA` and `INSTANCE_TYPE_PLAN`
- Once the cluster is created, eksctl will automatically switch the context to the new cluster. If you create another cluster, eksctl will once again switch the context to the newest cluster. If you wish to switch to another cluster, issue:

```
kubectl config get-contexts

# currently selected cluster will be marked with an asterisk (*)
# then switch contexts to the desired cluster

kubectl config use-context $USERNAME@$CLUSTER_NAME.$AWS_REGION.eksctl.io
```

**_NOTE:_ kubeconfig file and losing access to the cluster** 

The file that is used to configure access to clusters is called a kubeconfig file.
After you create your Amazon EKS cluster, you must configure your kubeconfig file with the AWS Command Line Interface (AWS CLI). This configuration allows you to connect to your cluster using the kubectl command line. 
This is being done automatically for us by eksctl (referenced a bit above).

This file should not be deleted or changed, unless the user knows what they are doing. If it is deleted, you will lose access to your cluster and have to run the following in order to regain access:
```
aws eks --region region update-kubeconfig --name cluster_name
```

4. Create the `.env.toml` file inside the `testground` folder and populate it (explained here as well https://github.com/testground/docs/blob/master/getting-started.md#configuration-envtoml):

**Note: The endpoint refers to the `testground-daemon` service, so depending on your setup, this could be, for example, a Load Balancer (default) fronting the kubernetes cluster and forwarding proper requests to the `tg-daemon` service, or a simple port forward to your local workstation.**

`.env.toml` will be output when the script finishes, so you simply need to copy the output and paste it into the `testground/.env.toml` file.
Example `.env.toml` file looks like this:

```
["aws"]
region = "$YOUR_REGION" # where the cluster will be created, for example eu-west-3 (default)
[client]
endpoint = "http://acca15c6ah3eh45n68ad6052c20ba9ec-1569872837.eu-west-3.elb.amazonaws.com:80"
user = "myname"
```

5. Setup the Load Balancer

The LB has only one listener on port 80 (HTTP) and it is completely open to the public Internet (0.0.0.0/0).
Optional: If you want to limit access to the LB, you can edit the SG attached to the LB in order to remove 0.0.0.0/0 and add your/your bastion's public IP.

Next you need to verify the service and obtain the DNS A record you will use to connect to:
```
kubectl get svc

NAME                              TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
testground-daemon                 LoadBalancer   10.100.16.157    acca15c6ah3eh45n68ad6052c20ba9ec-1569872837.eu-west-3.elb.amazonaws.com   80:31386/TCP   30d
```

You need to edit the `.env.toml` file in the `testground` folder and set the LB DNS A record as endpoint, for example:

```
endpoint = "http://acca15c6ah3eh45n68ad6052c20ba9ec-1569872837.eu-west-3.elb.amazonaws.com:80"
```

You can now run testground tests without having to port-forward to your laptop/bastion host.

**Please note that it might take a few minutes for the worker nodes to pass the AWS Load Balancer health checks. When this finishes, you will be able to run tests.**

6. Now you are ready to run testground tests:

```
# ping-pong test
testground run single --plan network --testcase ping-pong --builder docker:go --runner cluster:k8s --instances 2

# storm test
testground run single --plan=benchmarks --testcase=storm --builder=docker:go --runner=cluster:k8s --instances=10

# You can also use the provided script `eks/bash/perf.sh` to run multiple storm tests:

./perf.sh <run_count> <plan> <case> <instance_count> <builder> <runner>

# e.g. to schedule 10 runs with 50 pods/instances each:

./perf.sh 10 benchmarks storm 50 docker:go cluster:k8s
```

7. After the test has finished, obtain results:

```
testground collect --runner=cluster:k8s $RUN_ID
```

where the $RUN_ID will be generated and shown in the test output. It looks like this `cccb96126un8ibqhe7p0`.

8. After you are done, you can delete the cluster since AWS resources cost money while running:

Simply run the `testground_uninstall.sh` script. You will be prompted to remove the previously created resources, as the script will automatically detect them:

```
========================
PLEASE NOTE:
Running resources on AWS costs money.
This script should delete the following resources that have been created with the 'testground_install.sh' script:
  - 3 Cloudformation stacks created by eksctl - EKS cluster and 2 Nodegroups
(Note: if you created more than the default 2 nodegroups, then there will be more stacks)
  - EBS (Elastic Block Storage) volume in the selected Availability Zone
  - EFS (Elastic File System) in the selected AWS Region, along with a EFS mount target for the selected Availability Zone
Once the script finishes, you will be able to verify everything through the AWS console.
========================

Please select the cluster you want to remove
1) /home/ec2-user/infra/k8s/eks/.cluster/cluster1-region1.cs
2) /home/ec2-user/infra/k8s/eks/.cluster/cluster2-region1.cs
3) /home/ec2-user/infra/k8s/eks/.cluster/cluster1-region2.cs
4) Stop the uninstall script
#? 

```
**Please note that the `.cluster/CLUSTER_NAME-REGION.cs` file is created by the script and acts as a state file for the AWS resources. The `testground_uninstall.sh` script relies on this file in order to remove resources.<br/> If the file is removed or changed in any way, the uninstall script will output error message(s) stating this. In that case, the `.cs` file needs to be populated again, or the resources will have to be removed manually from your AWS account.  <br/>If you decide to create multiple clusters from the same laptop/bastion host, your `.cluster` folder will have multiple `CLUSTER_NAME-REGION.cs` files in it, each corresponding to one cluster.**

## Optional steps / Advanced setup

### Adding ssh access to worker nodes on setup

By default, ssh access to the worker nodes is not enabled. In case you do need to access your worker nodes, do the following:

- Generate an ssh key on your laptop/bastion (which you use to create the cluster):

```
ssh-keygen -t rsa -b 4096
```

The keys will be saved in `~/.ssh/` or `/home/$USERNAME/.ssh`, as both `id_rsa` and `id_rsa.pub`.

Then, in the installation script, edit the `make_cluster_config` function and add the following after `availabilityZones`:

```
    ssh:
      allow: true
      publicKeyPath: $SSH_PATH_INFRA  # note that this needs to reflect the path to your generated ssh key. Or you can set up a variable in the `.env` file and refer it here as an env var, like shown in the example
```

**Important note: when you allow ssh access like this, eksctl will create another AWS Security Group which allows ssh traffic (port 22) from `0.0.0.0/0` and `::/0`. This means that all public IPv4 and IPv6 addresses from the Internet will be able to access the hosts via ssh. The only line of defense would be the ssh key you have generated above. This is a very bad security practice and is not recommended.**

There is a workaround for this behavior, in short:

- You will need another Security Group created in the same VPC as the worker nodes. This SG will allow traffic from the bastion's SG (or it will whitelist your public IP)
- Attach this SG to the worker nodes on port 22
- Or you can always manually add a rule in the worker nodes' SG to whitelist the desired IP address on port 22
- Note that all manual additions will prevent the eksctl stack from getting deleted, please refer to the `delete cluster` section of this guide


### Adding ssh access to running worker nodes

In case you have already created a cluster using the script and want to add ssh access to your worker nodes, you may execute the `add-ssh-key-to-running-nodes.yml` on the cluster.
It will deploy a daemonset (one pod per worker node) which will deploy your public key to the nodes.

After that is done, you may delete the daemonset and proceed connecting to the worker nodes. Refer to the `.yml` for more details.

### Using the simple port-forward solution

**NOTE: By default, the script will deploy the testground service with a LB in front. If you would like to use port-forward instead of the LB, you need to edit the `eks/yaml/tg-testground-daemon-service.yml` to look like this:**

```
apiVersion: v1
kind: Service
metadata:
  name: testground-daemon
    labels:
    app: testground-daemon
spec:
  ports:
  - port: 8042
    protocol: TCP
  selector:
    app: testground-daemon
```

`.env.toml` example when using port-forward:

```
["aws"]
region = "$YOUR_REGION" # where the cluster will be created
[client]
endpoint = "http://localhost:8080"
user = "myname"
```

Issue the following command in another terminal window and you should see something like this:

```
kubectl port-forward service/testground-daemon 8080:8042
```

where 8042 is the port on which the `tg-daemon` is listening, and 8080 is a port on your local workstation/bastion host.

```
Forwarding from 127.0.0.1:8080 -> 8042
Forwarding from [::1]:8080 -> 8042
```

This means you are successfully forwarding traffic to the testground daemon from your localhost; remember that you've specified this in the `.env.toml` config file.

### Scaling a running cluster

Once the script creates a cluster, you will find a file called `$CLUSTER_NAME.yaml` in the `eks` folder you ran the script from. This is the eksctl config file for the nodegroups.
You can simply open the file and edit the field `desiredCapacity` for the `ng-2-plan` nodegroup, and add the number of nodes you wish to scale to.

Save the file and execute the following:

```
eksctl scale nodegroup --config-file=$CLUSTER_NAME.yaml --name=ng-2-plan
```

### Using a different AMI for the worker nodes

The AMI used for worker nodes defaults to Amazon EKS optimized Amazon Linux 2 v1.22 built on 08 Aug 2022, or by image name, `amazon-eks-node-1.22-v20220802`.
When you run the script, it will automatically find that image in your specified region and implement it into the config file.

If you need to specify a different image, you may change the variable `AMI_ID` in your `.env` file, for example change from the default:

```
AMI_ID=amazon-eks-node-1.22-v20220802
```
to:
```
AMI_ID=amazon-eks-node-1.23-v20220914
```

You may find a list of all AMI releases on the following link:

https://github.com/awslabs/amazon-eks-ami/releases

## Changing AWS Availability Zone for EBS/EFS/EKS

For now. there must be only one AZ because of the script logic; it defaults to `eu-west-3a`.
The AZ will be the same for EBS/EFS/Nodegroups, and it must correspond to the selected region (you cannot use `eu-west-3` as region and `eu-west-2a` as AZ).

If you need to change the Availability Zone for any reason, simply update the `AZ_SUFFIX` variable in you `.env` file.

## Docker image build and publish instructions

The images for `testground-daemon`, `testground-sidecar`, and `testground-sync-service` are being kept on public AWS ECR repositories.

Each image is tagged per the latest commit hash of the testground repository on github.

In order to find the latest commit, we need to `git pull` the latest testground code:

```
git pull
```

and then:

```
git rev-parse HEAD
```

which will give us the image tag that is being used for the docker image(s).
For example, at the time of writing this guide, images used for daemon and sidecar were called:

```
image: public.ecr.aws/n6b0k8i7/testground-daemon:80c5aca36114de067c33c8718cca95ef16db4c06

image: public.ecr.aws/n6b0k8i7/testground-sidecar:80c5aca36114de067c33c8718cca95ef16db4c06
```

which would correspond to the commit from Oct 11, 2022

```
80c5aca36114de067c33c8718cca95ef16db4c06
```

Guide and info on building and publishing to AWS ECR can be found on the following link:

https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html

## Cluster monitoring

This repo provides a script called `monitoring.sh` that will install the `kube-prometheus-stack` using helm.

This script will install the following:
https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

Once installed, you will be able to obtain the admin password for grafana by running the following command:
```
kubectl get secret --namespace default tg-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

You may then run the following in order to obtain the grafana pod name:
```
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=tg-monitoring" -o jsonpath="{.items[0].metadata.name}")
```

Finally, you may run the following in order to port-forward and access the grafana dashboard from your laptop by opening `localhost:3000` in your browser:
```
kubectl --namespace default port-forward $POD_NAME 3000
```

The monitoring stack can be uninstalled by running:
```
helm uninstall tg-monitoring
```

## Additional notes

When you create a new cluster, Amazon EKS creates an endpoint for the managed Kubernetes API server that you use to communicate with your cluster (using Kubernetes management tools such as kubectl). 
By default, this API server endpoint is public to the internet, and access to the API server is secured using a combination of AWS Identity and Access Management (IAM) and native Kubernetes Role Based Access Control (RBAC).

If you need to lock down your EKS public API access, please refer to the following link: 

https://eksctl.io/usage/vpc-cluster-access/#restricting-access-to-the-eks-kubernetes-public-api-endpoint

--

More information on max number of pods per node:

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html#AvailableIpPerENI