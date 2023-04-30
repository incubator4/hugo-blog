---
title: "Cert-Manager 自动管理证书"
date: 2022-03-11T23:54:41+08:00
tags:
  - traefik
  - docker
  - kubernetes
  - cert-manager
categories:
  - docker
  - kubernetes
---

## 前言

上一篇文章中说到了，Traefik 可以实现自动化 HTTPS 的加密，其原理是使用 Let’s Encrypt。  
然而由于 Traefik 在开启 LE 时，不仅需要一个 PVC 用于存储创建的证书，并且由于依赖了 PVC 的缘故，不支持多副本扩容。  
所以我们需要一个更加优秀的 HTTPS 方案，就是今天我们的主角 Cert-Manager 了。

## 原理介绍

Cert Manger 支持 HTTPS 的方式比较多，有 自签名 / CA 根证书 / Vault / Venafi / 外部引入 / ACME 的方式。  
由于我们需要自动化 HTTPS，所以原理上和上一期一样，需要使用 ACME 自动化配置 Let's Encrypted。

## CertManage 名词

### Issuer

Issuer 直接翻译过来就是颁发者，也就是用来颁发证书的单元。普通的 Issuer 是有命名空间隔离的资源。所以在整个集群中使用的话，需要 ClusterIssuer

### Certificate

Certificate 就是证书的概念了，证书需要引用 Issuer 来颁发证书。  
Certificate 引用了一个同命名空间的 Secret (不存在会自动创建) 用来存储 X509 证书。所以不用担心证书的存储问题，它使用了 Kubernetes 原生的方式来存储证书公私钥敏感信息。

### CertificateRequest

CertificateRequest 是一个用来记录证书向 Issuer 请求资源的过程。  
在一般情况下，都不需要手动创建，可以通过观察 CertificateRequest 的状态来判断证书的申请结果

## 安装 Traefik

Traefik 安装可以参考 [Traefik Automatic Https](https://blog.incubator4.com/post/traefik-automatic-https/)

## 安装 Cert-Manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.11.0 \
  --set installCRDs=true
```

### 创建 ClusterIssuer

Issuer 和 ClusterIssuer 一个是命名空间维度的，一个是集群维度的，这里我们为了方便直接创建 Cluster Issuer

我们使用 Acme 方式，这样能够自动签发证书

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: acme
spec:
  acme:
    email: <your-emaill-address>
    preferredChain: ""
    privateKeySecretRef:
      name: acme-cert-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              key: api-token
              name: cf-nsl-xyz-api-token
```

### 给 Ingress/IngressRoutes/GatewayAPI 签发证书

对于 Ingress 和 GatewayAPI 而言， Cert-Manager 已经做了集成，所以我们只需要在资源上添加注解即可，如下所示:

**Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    # add an annotation indicating the issuer to use.
    cert-manager.io/cluster-issuer: nameOfClusterIssuer
  name: myIngress
  namespace: myIngress
spec:
  rules:
    - host: example.com
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: myservice
                port:
                  number: 80
  tls: # < placing a host in the TLS config will determine what ends up in the cert's subjectAltNames
    - hosts:
        - example.com
      secretName: myingress-cert # < cert-manager will store the created certificate in this secret.
```

**Gateway**

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
  name: example
  annotations:
    cert-manager.io/issuer: foo
spec:
  gatewayClassName: foo
  listeners:
    - name: http
      hostname: example.com
      port: 443
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: example-com-tls
```

对于 IngressRoute 而言，我们需要手动创建 Certificate， 如下所示

**IngressRoute**

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: example
spec:
  entryPoints: # We listen to requests coming from ports 80 and 443
    - web
    - websecure
  routes:
    - match: Host(`example.domain.com`)
      kind: Rule
      services:
        - name: example # Requests will be forwarded to this service
          port: 80
  tls:
    secretName: example-cert
```

**Certificate**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
spec:
  dnsNames:
    - example.domain.com
  secretName: example-cert
  issuerRef:
    name: acme
    kind: ClusterIssuer
```
