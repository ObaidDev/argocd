# Installation :
- intall cert-manager using helm.
- install haproxy ingress using helm


### Install Cert Manager
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

```bash 
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```


## Nginx Ingress 

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

```

```bash
helm install main-ingress ingress-nginx/ingress-nginx --set controller.service.annotations."lo
ad-balancer\.hetzner\.cloud/location"=nbg1
```

Check [https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/docs/guides/load-balancer/quickstart.md]



#### create ingress classs : 

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: haproxy
spec:
  controller: haproxy.org/ingress-controller
```