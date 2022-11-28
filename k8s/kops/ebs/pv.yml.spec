kind: PersistentVolume
apiVersion: v1
metadata:
  name: testground-daemon-datadir-pv
  labels:
    type: aws-ebs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: "gp2-retain"
  awsElasticBlockStore:
    volumeID: ${TG_EBS_DATADIR_VOLUME_ID}
    fsType: ext4
