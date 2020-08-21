---
title: "Docker从零入门 2 运行Docker容器"
date: 2020-08-15T20:21:38+08:00
---

在前一节[Docker从零入门 1 安装和配置Docker环境](/post/docker-guide-1)中简单的阐述了docker的安装过程，本节的主要目标是在装完docker的操作系统上运行第一个容器

---

## 前言
如果在linux环境下，firewalld和ufw可能会造成docker映射的端口无法访问，良好的做法当然是按需打开需要的端口。因为这是教学，所以为了方便，可以关闭防火墙。

 redhat下firewalld关闭  
`sudo systemctl disable --now friewalld`  
debian下ufw关闭   
`sudo systemctl disable --now ufw`  

**重点 关闭防火墙之后导致iptables规则变化，必须重启docker进程**

`sudo systemctl restart docker`

## 了解相关Docker指令

```bash
docker ps # 列出容器
#CONTAINER ID     IMAGE   COMMAND     CREATED   STATUS    PORTS NAMES
```
这里可以看到没有容器，这是因为我们还没有开始运行容器
```bash
docker images # 列出镜像
# REPOSITORY      TAG        IMAGE ID        CREATED         SIZE
```
同样的，我们本地还没有镜像，所以是空白的  
其他可以在终端中输入`docker help`来查看所有的docker相关命令

## 运行第一个容器

#### 即时的容器
在终端中运行以下命令
```bash
docker run --rm alpine /bin/echo "Hello world"
# Hello world
```
我们在终端中就在容器中运行了一个HelloWorld指令

#### 交互式的容器
```bash
docker run --rm -it alpine /bin/sh
# ~ 
```
这样就进入到了容器环境中的shell

#### 持久运行的容器
```bash
docker run -d -p 8080:80 --name=nginx nginx
# Unable to find image 'nginx:latest' locally
# latest: Pulling from library/nginx
# bf5952930446: Pull complete
# cb9a6de05e5a: Pull complete
# 9513ea0afb93: Pull complete
# b49ea07d2e93: Pull complete
# a5e4a503d449: Pull complete
# Digest: 
# sha256:b0ad43f7ee5edbc0effbc14645ae7055e21bc1973aee5150745632a24a752661
# Status: Downloaded newer image for nginx:latest
# 05a37ec818a5b461fde5bb3de44f0f930a93ec826fa1c30abf31d3aaff58047d
```
这样我们在本地的8080端口就跑了一个nginx容器，如果端口被占用或者因为防火墙等其他原因，换用别的端口即可  
通过curl访问8080端口`curl localhost:8080` 或者网页访问

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
就会发现nginx已经跑起来了

## docker run的参数
可以观察到，在之前运行的命令里带了很多参数，这里简单的解释下各个重要的参数的意义

|   参数    |                  值                   |                             说明                             |
| :-------: | :-----------------------------------: | :----------------------------------------------------------: |
|    -i     |                  无                   | 以交互模式运行容器，通常与 -t 同时使用。如果不加-i进入容器的交互式shell，将无法使用 |
|    -t     |                  无                   | 为容器重新分配一个伪输入终端，通常与 -i 同时使用。同理，交互式所需，通常可以缩写成docker run -it |
|    -d     |                  无                   |               后台运行容器，会返回一个容器的id               |
|  --name   |                字符串                 | --name=nginx 如果不指定name，会随机gg生成一个名称，自定义名称会方便管理 |
|    -p     |      外部端口(int):容器端口(int)      |     -p 8080:80 指的是把容器中的端口80映射到主机的8080上      |
|           |         ip:外部端口:容器端口          | 特别的，如果有多个ip地址或者希望只能被特定ip地址访问，可以使用 -p 127.0.0.1:8080:80来限定监听的ip地址 |
|           |               容器端口                | 如果不指定主机端口，如 -p 80 则把80端口随机映射到一个主机的可用端口上 |
|    -P     |                  无                   |                把容器中的所有端口随机映射出来                |
|   --rm    |                  无                   | 使得容器在停止之后直接删除,在需要临时使用容器的时候可以加上该参数，减少后续人为清除容器资源，节省劳动力 |
|    -e     |                foo=bar                | 指定容器运行环境中的环境变量，-e foo=bar 容器中添加环境变量foo的值为bar字符串。通常来说，部分官方认证的i容器，如mysql,postgres,mongo等，都可以通过指定环境变量的形式自定义初始帐号密码 |
|    -v     |          主机路径:容器内路径          | -v通过类似于磁盘穿透的形式，把主机中的目录挂载到容器中。常见交互模式下，可以通过挂载目录的模式下，使用容器中的环境来操作主机磁盘上的数据。 并且，可以通过挂载的形式，来实现docker容器数据的持久化 |
| --restart | [no,always,on-failure,unless-stopeed] | 设置容器的重启策略，通常来说重启策略是no,在宿主机重启或者docker重启后i容器会停止运行，所以可以按需修改重启策略来使得容器自动重启 |

## 查看和管理容器

通过一定的操作，可以启动一些容器，这一小节主要来介绍如何查看和管理容器

#### 查看容器

使用`docker ps` 即可查看当前正在运行的容器  
有些时候，需要查看未启动的，或者已经停止的容器，使用-a参数，`docker ps -a`可以看到所有状态的容器
通过`docker ps -q`可以只输出容器的id,可以方便一键删除容器，关于删除的部分留到下面专门的章节再做介绍

#### 管理容器
管理 容器需要使用容器的id和名称。使用容器id时，不必使用全部长度的id,只要不造成即可，即u对于容器id为131e8487e3ef的id,131ey就可以表示该容器，若是有重复的，往后继续补位即可  
使用容器名字时，则需要输入全部名称才能成功匹配当前容器，因此，在前文建议使用--name字段来给容器指定一个特别的名字，不仅为了使得能够清晰的辨别容器的功能，也使得操作容器h变得方便  

`docker start 容器id/名称`  来启动一个容器

`docker stop 容器id/名称` 停止一个容器（对有重启策略的容器可能不生效）

`docker rm 容器id/名称` 删除一个已停止容器，对于活动中的容器而言，则需要加上-f的force选项来删除

#### 管理镜像

`docker images` 同 `docker image list` 查看镜像列表  
`docker rmi 镜像名称/id` 删除一个镜像

#### 批量删除

单独的开一个小节讲一下 如何批量删除容器和镜像,因为实际业务上遇到过类似的  

`docker rm -f $(docker ps -aq)`  删除全部容器  

`docker rm -f $(docker ps -a|grep $VAR|awk '{print $1}')` 删除带有$VAR值的 容器  

同理对于镜像  

`docker rmi -f $(docker images -q)` 删除全部镜像  

`docker rmi -f $(docker images|grep none|awk '{print $3}')` 删除带有none字段的全部镜像（多半带有none的为r中间缓存）

特别的，可以通过`docker image prune`来释放未使用镜像的空间（慎用）



