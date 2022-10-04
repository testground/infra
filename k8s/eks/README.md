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

Specific version (required when your cluster is not compatible with the latest version, v1.22 used in the example below):

```
curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**4. AWS CLI (v2) with AWS credentials and ECR login**

**NOTE: You decide which AWS region you want to use, there are no limitations when it comes to this script. A list can be found here:**

https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html

First install the aws cli v2 (note that v1 is already installed if using amazon linux, so you will first need to remove the v1 and install v2):

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install

Then configure the credentials:

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

Verify you can log into ECR using the set credentials:

```
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# or in this case since the images are moved to a public repo:

aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/n6b0k8i7
```

**5. eksctl**

Official installation guide:

https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html

```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
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

2. You need to populate the `.env` file with the needed parameters before creating the cluster. It is located in `infra/k8s/eks/`

The variables are divided into two main groups - `REQUIRED TO BE CHANGED` and `OPTIONAL TO BE CHANGED/ CAN BE LEFT WITH DEFAULTS`.

The `REQUIRED` variables need to be populated by the user - `CLUSTER_NAME` (unique cluster name, so your EKS cluster will be called `eks-$CLUSTER_NAME-cluster)`, `REGION` (AWS region where you will create your resources), and `AVAILABILITY_ZONE` (AZ within the selected region where you want your resources created)

The `OPTIONAL/DEFAULTS` are safe to remain unchanged, but you are free to modify them to suit your needs. Please refer to the `.env` file for more information about each parameter.

3. Run the installation script `./testground_install.sh`; note that it requires the `.env` file to be populated in order to run properly. In case of any missing variables, the setup will fail and you will get an error message

The script explained in short:

- Takes approx. 15-20 minutes to provision a cluster with 2 worker nodegroups, along with all other necessary resources and cluster workloads
- All installation steps have been divided into functions, located in the `eks/bash/functions.sh` script
- The script calls functions one by one
- Output of every step is logged into a master log file that can be retrieved and reviewed, or even tailed in real time
- It can also be used to uninstall a provisioned cluster; one of the first steps in the script is checking for existing resources
- The `functions.sh` file relies on the content of `eks/yaml` - all cluster resources are located inside this folder
- If you need to scale the worker nodegroups on setup, you are able to edit the `.env` file parameters - `DESIRED_CAPACITY_INFRA` and `DESIRED_CAPACITY_PLAN`
- You are also able to change the worker node instance type - `INSTANCE_TYPE_INFRA` and `INSTANCE_TYPE_PLAN`
- Once the cluster is created, eksctl will automatically switch the context to the new cluster. If you create another cluster, eksctl will once again switch the context to the newest cluster. If you wish to switch to another cluster, issue:

```
kubectl config get-contexts

# currently selected cluster will be mark with an asterisk (*)
# then switch contexts to the desired cluster

kubectl config use-context $USERNAME@$CLUSTER_NAME.$AWS_REGION.eksctl.io
```

4. Create the `.env.toml` file inside the `testground` folder and populate it (explained here as well https://github.com/testground/docs/blob/master/getting-started.md#configuration-envtoml):

**Note: The endpoint refers to the `testground-daemon` service, so depending on your setup, this could be, for example, a Load Balancer fronting the kubernetes cluster and forwarding proper requests to the `tg-daemon` service, or a simple port forward to your local workstation.**

`.env.toml` example:

```
["aws"]
region = "$YOUR_REGION" # where the cluster will be created
[client] # Note: Only one endpoint can be active, please refer to steps 5. and 6. for clarification
endpoint = "http://localhost:8080" # if using port-forwarding
endpoint = "http://acca15c6ah3eh45n68ad6052c20ba9ec-1569872837.eu-west-3.elb.amazonaws.com:80" # if using LB (default)
user = "myname"
```

5. Using the simple port-forward solution

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

6. Setup the Load Balancer

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

7. Now you are ready to run testground tests:

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

8. After the test has finished, obtain results:

```
testground collect --runner=cluster:k8s $RUN_ID
```

where the $RUN_ID will be generated and shown in the test output. It looks like this `cccb96126un8ibqhe7p0`.

9. After you are done, you can delete the cluster since AWS resources cost money while running:

Simply run the `testground_install.sh` script again and you will be prompted to remove the previously created resources, as the script will automatically detect them:

```
 "We found that you already have a cluster provisioned with this script"
 "Do you want to remove it? (y/n)?"
```

## Optional steps

### Adding SSH access to worker nodes on setup

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


### Adding SSH access to running worker nodes

In case you have already created a cluster using the script and want to add SSH access to your worker nodes, you may execute the `add-ssh-key-to-running-nodes.yml` on the cluster.
It will deploy a daemonset (one pod per worker node) which will deploy your public key to the nodes.

After that is done, you may delete the daemonset and proceed connecting to the worker nodes. Refer to the `.yml` for more details.

### Scaling a running cluster

Once the script creates a cluster, you will find a file called `$CLUSTER_NAME.yaml` in the `eks` folder you ran the script from. This is the eksctl config file for the nodegroups.
You can simply open the file and edit the field `desiredCapacity` for the `ng-2-plan` nodegroup, and add the number of nodes you wish to scale to.

Save the file and execute the following:

```
eksctl scale nodegroup --config-file=$CLUSTER_NAME.yaml --name=ng-2-plan
```

## Additional notes

When you create a new cluster, Amazon EKS creates an endpoint for the managed Kubernetes API server that you use to communicate with your cluster (using Kubernetes management tools such as kubectl). 
By default, this API server endpoint is public to the internet, and access to the API server is secured using a combination of AWS Identity and Access Management (IAM) and native Kubernetes Role Based Access Control (RBAC).

If you need to lock down your EKS public API access, please refer to the following link: 

https://eksctl.io/usage/vpc-cluster-access/#restricting-access-to-the-eks-kubernetes-public-api-endpoint