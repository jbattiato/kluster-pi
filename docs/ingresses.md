# Ingresses

An ingress in kubernetes is required if you want to expose a web server to the network (outside the kubernetes cluster).

## Ingress Nginx

[https://kubernetes.github.io/ingress-nginx/](https://kubernetes.github.io/ingress-nginx/)

Installing the `ingress-nginx` ingress is as easy as applying the manifest of its deployment:

``` bash
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml"
```
