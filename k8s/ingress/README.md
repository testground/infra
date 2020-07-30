1. Add `cert-manager` namespace
```
kubectl create namespace cert-manager
```

2. Install cert-manager CRDs
```
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml
```

3. Install nginx
```
helm install --values nginx-ingress.yaml tg stable/nginx-ingress
```

4. Manually add CNAME records for Ingress points to Route53
```
kubectl get service
```

5. Install ClusterIssuer for Let's Encrypt
```
kubectl apply -f cluster-issuer-prod.yaml
```

6. Install Ingress resources for Testground Daemon and Grafana
```
kubectl apply -f testground-daemon.yml -f grafana.yml
```
