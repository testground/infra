## Background

Testground AMI image is currently based on `k8s-1.17-debian-stretch-amd64-hvm-ebs-2020-01-17`

You can get a specific AMI for a given region with:

```
aws ec2 describe-images --region eu-west-2  --output table \
  --owners 383156758163 \
  --query "sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]" \
  --filters "Name=name,Values=*-debian-stretch-*"
```

---

## Upgrade strategy

Every time a new `kops` image is available, we should re-create a cluster using it, instead of the Testground AMI, and review which Docker images have been upgraded and modify our `docker-pull-images.sh` script.

Once we build a new image with `make build-ami-image`, we should then distribute that image to all regions with `distribute-image.sh`.
