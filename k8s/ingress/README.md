1. kubectl create namespace cert-manager

2. kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml

3. helm install --values nginx-ingress.yaml tg stable/nginx-ingress

4. manually add CNAME records for ingress points to Route53

5. 7. apply ingress for daemon and grafana
