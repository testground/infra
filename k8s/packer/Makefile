testground-ami-images:
	packer build -var 'source_ami=ami-093dda5e01f6102a8' -var 'aws_region=eu-central-1' testground-ami.json
	packer build -var 'source_ami=ami-05516775460f4eb85' -var 'aws_region=eu-west-2'    testground-ami.json
