## Background

Testground AMI image is currently based on `ami-05516775460f4eb85` (k8s-1.17-debian-stretch-amd64-hvm-ebs-2020-01-17)

You can review `kops` images with:

```
aws ec2 describe-images --region eu-west-2  --output table \
  --owners 383156758163 \
  --query "sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]" \
  --filters "Name=name,Values=*-debian-stretch-*"
```

---

## Upgrade strategy

Every time a new `kops` image is available, we should re-create a cluster using it, instead of the Testground AMI, and review which Docker images have been upgraded and modify our `docker-pull-images.sh` script.
