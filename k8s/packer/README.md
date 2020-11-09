## Background

Testground AMI image is currently based on `099720109477/ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20201014` (since this is what kops v1.18.2 is using)

---

## Upgrade strategy

Every time a new `kops` image is available, we should re-create a cluster using it, instead of the Testground AMI, and review which Docker images have been upgraded and modify our `docker-pull-images.sh` script.

Once we build a new image with `make build-ami-image`, we should then distribute that image to all regions with `distribute-image.sh`.

Once we distribute a new image to all regions, then make it public with `make-image-public.sh` so that the community can use it.
