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

### ACME 相关资源

####

## 安装

### 创建 namespace

为了方便管理，创建一个独立的 namespace
`kubectl create ns traefik-system`

### 获取云厂商 AKSK

traefik 支持如下[供应商](https://doc.traefik.io/traefik/https/acme/#providers)
这里我用的是阿里云账户，为了最小化权限管理，使用了 RAM 账户，获取 RAM 账户的 AKSK 之后，记得给账户添加读写权限，这里给 AKSK 创建一个 secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alicloud-secret
  namespace: traefik-system
data:
  ALICLOUD_ACCESS_KEY: ${base64 access_key}
  ALICLOUD_SECRET_KEY: ${base64 secret_key}
type: Opaque
```

### helm 安装

[traefik helm chart github](https://github.com/traefik/traefik-helm-chart/tree/master/traefik)在这里
我们需要 helm 3.0 版本以上
首先添加 traefik 的 helm repo
`helm repo add traefik https://helm.traefik.io/traefik`

### 配置额外的 values

新建一个`values.yaml`文件

```yaml
additionalArguments:
  - --providers.kubernetesingress.ingressclass=traefik # k8s ingress的class 名字叫做 traefik
  - --certificatesresolvers.le.acme.dnschallenge.provider=alidns # provider使用alidns
  - --certificatesresolvers.le.acme.storage=/data/acme.json #路径要和下面的pvc匹配
  - --certificatesresolvers.le.acme.email=aries0robin@gmail.com
#注意 这里的certificatesresolvers.le, le只是一个certResolver的名字，也就是我们可以配置多个resolver，独立的ingress中可以配置独立的resolver
envFrom:
  - secretRef:
      name: alicloud-secret
# 这里填写刚才我们创建的secret名字，注意需要在一个namespace中
ingressClass:
  enabled: true # 开启ingressclass
  fallbackApiVersion: ""
  isDefaultClass: true
# 由于我们用了acme storage 所以需要pvc存储实际申请的证书的信息，空间不用太大 128m即可
persistence:
  accessMode: ReadWriteOnce
  annotations: {}
  enabled: true
  name: data
  path: /data
  size: 128Mi
  storageClass: nfs-client # storageclass 根据需要填写
ports:
  metrics:
    expose: false
    exposedPort: 9100
    port: 9100
    protocol: TCP
  traefik:
    expose: false
    exposedPort: 9000
    port: 9000
    protocol: TCP
  web:
    expose: true
    exposedPort: 80
    port: 8000
    # hostPort: 8000
    protocol: TCP
  websecure:
    expose: true
    exposedPort: 443
    port: 8443
    # hostPort: 8443
    protocol: TCP
    tls:
      certResolver: le # 配置默认的resolver名字，和上文一样
      domains: # 配置的主域名和从泛域名， 这里只有匹配的域名才会自动加证书
        - main: incubator4.com
          sans: # 注意 多级泛域名需要单独填写，不支持*.test.com 匹配a.b.c.test.com
            - "*.incubator4.com"
            - "*.rancher.incubator4.com"
      enabled: true
      options: ""
providers:
  kubernetesCRD:
    enabled: true
    namespaces: []
  kubernetesIngress:
    enabled: true
    namespaces: []
    publishedService:
      enabled: false
deployment:
  enabled: true
  kind: Deployment # 可以选择Daemonset的形式
  replicas: 1
service:
  enabled: true
  type: ClusterIP # 可以选用ClusterIP / LoadBalancer
```

### 根据集群具体情况使用 deployment 还是 daemonset

请各位同学根据自己情况斟酌使用哪种方式

#### 使用 daemonset

daemonset 使用 node selector 使得 pod 落到特定的 node 上，启用 hostport 让容器绑定该机器的物理端口，可以直接用 node-ip:node-port 访问 pod。

PC -> node Port -> pod port

这种方式不经过 svc，适用于 裸金属 kubernetes，能直接通过 ip 连接到 node 节点的情况

#### 使用 deployment

众所周知，云厂商提供了 LoadBalancer 的形式，使得创建的 service 具有一个公网 IP，可以在外网（或者内网，一般指集群外）直接访问 service
这种方式使用 loadbalance 形式的 service 为 traefik deployment 提供负载均衡
而后直接访问 loadbalance 的 ip 就相当于直接访问到 traefik 的 svc 了

### 部署

一句话
`helm install traefik traefik/traefik -n traefik-system -f values.yaml`

### 访问 dashboard

在 traefik-system 中创建如下资源

```yaml
kind: IngressRoute
metadata:
  name: traefik-dashboard-route
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`traefik.incubator4.com`)
      kind: Rule
      services:
        - kind: TraefikService
          name: api@internal
```

应用之后就可以通过 http 访问了

![dashboard](/image/traefik/image-20210916003801496.png)

### 测试自动加密证书

在上文 yaml 资源中的 entryPoint 添加一个 websecure，如下所示

```yaml
kind: IngressRoute
metadata:
  name: traefik-dashboard-route
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`traefik.incubator4.com`)
      kind: Rule
      services:
        - kind: TraefikService
          name: api@internal
```

部署完成之后，把协议修改成 https 即可

![https-dashboard](data:image/png;base64,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)

注： 由于 LE 发证书需要一定的时间，受网络环境 集群性能影响，所以过快打开可能会出现证书错误的情况，traefik 会默认使用 traefik default 的证书，可以通过看 traefik pod 的 log 来 debug