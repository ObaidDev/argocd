# Installation :
- intall cert-manager using helm.
- install haproxy ingress using helm




## Haproxy Ingress 

```
helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm repo update

```

```
helm install my-haproxy4 haproxytech/haproxy \
  --set service.type=LoadBalancer \
  --set service.annotations."load-balancer\.hetzner\.cloud/location"=nbg1
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