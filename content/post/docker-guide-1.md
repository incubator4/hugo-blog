---
title: "Docker从零入门 1 安装和配置Docker环境"
date: 2020-08-15T20:21:36+08:00
tags:
  - docker
categories:
  - docker
---

在一般说到Docker的情况下，通常认为是Linux的环境。然而，即使你没有Linux环境，也可以用Windows或者macOS来安装Docker组件，默认情况下，使用x86的架构，arm的平台由于通用性不是那么的高，暂时没有在教程里写到。

以及，由于网络原因，都能够在国内镜像站环境下提供较快的docker安装环境

## Linux 下的Docker环境安装

#### 以Ubuntu为代表的Debian系

###### 1.首先安装必须的apt https组件和ca证书扩展  
```bash
sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
```
###### 2.添加Docker的存储仓库  
①. 官方源  
```bash
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
②. 阿里源  
```bash
sudo add-apt-repository \
   "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
###### 3.添加gpg证书
①. 官方源  
`curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -`
②. 阿里源 
`curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -`
###### 3.5 验证key是否生效
```bash
sudo apt-key fingerprint 0EBFCD88

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]
```
请注意有可能由于版本原因，key的实际内容并不是完全一致的
###### 4. 安装Doker CE
`sudo apt install -y docker-ce`
####### 5.查看Docker版本
`sudo docker -v`

#### 以Centos为代表的Redhat系

###### 1.安装yum组件和相关驱动
`sudo yum install -y yum-utils device-mapper-persistent-data lvm2`

###### 2.添加Docker源

①. 官方源  
```bash
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```
②. 阿里源 
```bash
sudo yum-config-manager \
    --add-repo \
    http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```
###### 2.5
额外的 centos8 和 fedora 可以使用dnf包管理器安装fedora的源
```bash
sudo dnf install -y dnf-plugins-core

sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
```
当然 centos8仍然可以使用yum安装，但是由于epel8中并未添加container.io，可能需要手动添加container.io

###### 3
安装 docker
`sudo yum install docker-ce`
如果遇上了container.io报错问题，需要安装container.io

```bash
sudo dnf install -y \
https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
```
当然，docker官方的rpm包也可以换成阿里云源的rpm包
```bash
sudo dnf install -y \
https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
```

然后再次安装docker-ce即可

#### linux下的小tips

###### 使用systemd 做开机自启和启动docker
```bash
sudo systemctl enable docker
sudo systemctl start docker
```

###### 非root用户操作docker权限
创建docker 组(一般安装都已创建)  
`sudo groupadd docker`  
把当前用户加入到docker组  
`sudo gpasswd -a ${USER} docker`  
重启docker 服务  
`sudo systemctl restart docker`  
退出当前用户并且重新登录测试（或者打开新的终端）  
`docker ps`


## macOS 和 windows下的Docker环境安装

相比linux 而言，Docker提供了Docker Desktop软件包方便一键安装，可以直接在以下路径下载dmg或者exe安装
https://www.docker.com/products/docker-desktop

#### WSL2 支持

在windows 2004下，如果已经安装并且启用了WSL2（本文不多做介绍）
可以在Docker的管理界面中对所有wsl2的子系统开启docker环境（原生linux docker）


## docker源等相关配置

新版的docker尽量使用/etc/docker/daemon.json文件配置，目录和文件不存在创建即可
```json
{   
	"exec-opts": ["native.cgroupdriver=systemd"], 
	"data-root": "/var/lib/docker", 
	"registry-mirrors": [  
          "http://registry.docker-cn.com",
          "http://hub-mirror.c.163.com",
          "http://docker.mirrors.ustc.edu.cn"
		]
}
```

|       常见参数        |      默认值      |                             说明                             |
| :-------------------: | :--------------: | :----------------------------------------------------------: |
|      "exec-opts"      |     不填即可     |   配置cgroup 默认不配置是cgroupfs kubernetes 的kubelet需要   |
|       data-root       | "var/lib/docker" | docker存储镜像等数据的目录，一般不用配置或者默认,空间不够的情况可以修改为其他分区或者盘 |
|   registry-mirrors    |        无        | 镜像源，由于国内网络原因，可以通过配置镜像源一定程度加快访问 |
| "insecure-registries" |  无/string列表   |        使用http连接的私有源（或者https证书错误的源）         |

修改完之后需要重启docker  
linux下使用`sudo systemctl restart docker`
docker desktop 重启软件