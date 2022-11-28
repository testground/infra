---
apiVersion: v1
kind: Service
metadata:
  name: testground-daemon
  labels:
    app: testground-daemon
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "alpha.eksctl.io/cluster-name=${CLUSTER_NAME}"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8042
  selector:
    app: testground-daemon