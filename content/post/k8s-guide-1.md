---
title: "K8s入门 1 架构简单简介"
date: 2020-12-28T10:04:24+08:00
tags:
  - docker
  - kubernetes
categories:
  - docker
  - kubernetes
---
## 前言

虽然，即使完全不了解k8s的架构，也可以直接上手安装并且使用。但是考虑到后续的学习成本和曲线问题，专门开了一篇简单的介绍一下k8s系统运行层面的架构

## 架构

![components](/image/k8s/components-of-kubernetes.svg)

先贴一张官方自己画的图，然后简单的介绍一下各个组件的功能。

首先，k8s的架构分为master和node，master是控制平面，负责管理整个集群的容器调度，任务队列，api控制等等。

node是工作平面，负责实际分配工作的具体负载，执行调度到该节点的任务。

### master节点

#### api server
![api](/image/k8s/api.svg)

首先要说的是，k8s采用了声明式的模式。只要写明需要创建资源的yaml清单，应用到k8s集群中，相应的，就会在集群中创建相关的资源。

并且对于所有的资源，都遵从restful的模型，都可以get delete update watch，所以就需要一套api来控制资源。
api server，顾名思义，就是用来控制k8s整体资源的API服务，所有的对资源改动和查询的请求都需要访问api server来操作，这其实和后端的业务模式是类似的，明白了这点就不难理解。

#### etcd
![etcd](/image/k8s/etcd.svg)

这个组件并非k8s独有的，etcd是一个分布式、高可用的键值数据库。在集群中用于存储当前集群的状态，已经部署的资源，资源的内容，资源的各个状态等，可以在意外重启或其他情况时恢复集群的状态而不至于丢失数据。

并且，etcd是一个高可用的数据库，master节点也可以是多个，多个master节点有多个etcd数据库。在遇到master节点意外停机的情况下，不会丢失对集群的控制。

这里要说的一点是，在某些k8s版本中，使用的并非是etcd来存储集群状态的，原则上每一个持久化的数据库，mysql postgresql 甚至sqlite都是可以用来作为集群状态的持久化存储的，例如k8s的轻量版本k3s用的就是sqlite来减少性能的开销。使用etcd是因为在标准的k8s中，它是一个最好的选择。

#### controller manager
![c-m](/image/k8s/c-m.svg)

controller manager 是各种controller的管理者,是集群内部的管理控制中心。而controller则是用来控制集群中的各种资源。

有用来控制pod数列的repication controller，用来控制节点的node controller，控制命名空间的namespace controller，控制服务的service controller等等。

简单的来说，就是控制集群能够正确分配各种组件的数量和状态的控制管理器。

##### cloud controller manager
![c-m](/image/k8s/c-c-m.svg)

可以看到有一个带虚线的cloud controller manager，这个是云厂商针对k8s定制版本推出的，非标准k8s定义控制器，但是有需要实现一些特有资源。例如云厂商自己的负载均衡器等等，那就需要cloud controller manager 去管理这些自有的controller资源

##### cloud controller api

同样的，和apiserver类似，cloud controller manager，需要通过自定义api组件的方式，实现对ccm中的controller资源的控制，来达到调度自有的资源。

#### kube schedule
![sched](/image/k8s/sched.svg)

顾名思义，kube schedule组件是一个用于调度的组件，当通过api server创建的资源请求成功后，就会在kube schedule中加入队列。而后根据队列FIFO的原则，决定每一个资源的创建，调度分配等等。创建的pod会被动态的调度到不同的节点，就是kube schedule在中间起到的作用。

### worker节点

#### kubelet
![kubelet](/image/k8s/kubelet.svg)

kubelet 运行在每一个节点上，用于实际管控节点上的资源。例如决定节点用的容器运行时，向master节点注册当前worker节点的地址hostname等信息等等。是实际控制节点该拉取镜像，运行镜像的工作进程。

#### kube proxy
![k-proxy](/image/k8s/k-proxy.svg)

kube proxy是运行在每个节点上，并且进行tcp udp sctp等协议的转发，使得集群多个工作节点之间的服务能够互相访问。

根据CNI网络插件的不同，kube proxy配合CNI插件，有不同的网络实现形式。但是不管是哪一种实现形式，使得不同的节点上的不同pod，可以互相访问。