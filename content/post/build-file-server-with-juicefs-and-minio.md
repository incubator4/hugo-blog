---
title: "使用 Juicefs 和 Minio 搭建简单上手的高可用存储"
date: 2022-11-15T13:38:30+08:00
tags:
  - juicefs
  - minio
  - s3
  - object storage
categories:
  - docker
  - minio
---

## 前言

最近发现 Juicefs 基于 S3 的对象存储，可以简单的实现比较好用的高可用存储方案，于是把安装部署过程和可能会遇到的坑点记录下来。

### 这篇文章的目标用户

- 需要有 Linux 服务器，并且需要有多个磁盘(分区)，直通物理磁盘最佳，虚拟磁盘和分区也可以用于构建

- 需要对 Docker 有一定程度的了解

- 想要构建(家庭高可用存储)的读者

### 对比其他的方案

众所周知，高可用存储目前有类似，GlusterFS, Ceph, ZFS 等单机/集群的存储方案。

![ceph](/image/ceph/3B38BC5B-6A17-4C6B-9CF9-A796BC3C4E8B.jpeg)

其中，GlusterFS,HDFS 这些方案，由于需要多副本多节点的支撑，对家庭用户来说开销太高。 而 Ceph 集群也是同理,即使可以根据需求，切换使用多副本和纠删码的模式，但其运维的成本过于高。因此考虑了近几年的 Minio 方案。 Minio 是一个开源的 S3 兼容的对象存储，使用纠删码机制，具有读写仲裁，而且部署和数据恢复方便。

## 安装 Minio

![minio-server](/image/minio/minio-server.jpeg)

我有一台 12 盘位的服务器，用来作为 Minio 的服务器

### 安装系统

安装任意的 Linux 系统都可以， Ubuntu/Debian/Centos/Suse 都可。

### 安装 Docker

安装方式可以参考 [**这里**](/post/docker-guide-1/)

### 准备你的硬盘(分区)

```bash
$ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 279.4G  0 disk
|-sda1   8:1    0 278.4G  0 part /
|-sda2   8:2    0     1K  0 part
`-sda5   8:5    0   976M  0 part [SWAP]
sdb      8:16   0 279.4G  0 disk
sdc      8:32   0   2.7T  0 disk /mnt/disk1
sdd      8:48   0   2.7T  0 disk /mnt/disk2
sde      8:64   0   2.7T  0 disk /mnt/disk3
sdf      8:80   0   2.7T  0 disk /mnt/disk4
sdg      8:96   0   2.7T  0 disk /mnt/disk6
sdh      8:112  0   2.7T  0 disk /mnt/disk5
```

这里可以看到我有六个硬盘，有多个分区也是可以的。使用以下命令把磁盘格式化成 xfs 格式。

```bash
$ mkfs.xfs /dev/sdc -L DISK1
```

并且给磁盘打上相应的标签，我这里是对应 DISK1-6，这样在挂载磁盘的时候，就不会出现重启后磁盘读取顺序错误，导致挂载位置错误。`/etc/fstab` 如下所示。

```
# 以上省略其他系统盘的挂载
LABEL=DISK1 /mnt/disk1 xfs defaults,noatime 0 2
LABEL=DISK2 /mnt/disk2 xfs defaults,noatime 0 2
LABEL=DISK3 /mnt/disk3 xfs defaults,noatime 0 2
LABEL=DISK4 /mnt/disk4 xfs defaults,noatime 0 2
LABEL=DISK5 /mnt/disk5 xfs defaults,noatime 0 2
LABEL=DISK6 /mnt/disk6 xfs defaults,noatime 0 2
```

首次更改完`/etc/fstab`后，使用 `mount -a` 命令刷新一下挂载配置，然后用`lsblk`命令即可看到磁盘被正确挂载了。

### 运行 Minio

找一个目录，例如`$HOME/minio` 存放运行 minio 所需的 `docker-compose.yaml` 文件，内容如下:

```yaml
version: "3.7"

# Settings and configurations that are common for all containers
x-minio-common: &minio-common
  image: quay.io/minio/minio:RELEASE.2022-11-11T03-44-20Z
  # 这里对应的磁盘数量
  command: server --console-address ":9001" /disk{1...6}
  ports:
    - 9000:9000
    - 9001:9001
  expose:
    - "9000"
    - "9001"
  restart: unless-stopped
  environment:
    # 开放 metrics 指标，也可以去掉这一条
    MINIO_PROMETHEUS_AUTH_TYPE: public
    # 设置默认用户名和密码
    # MINIO_ROOT_USER: minioadmin
    # MINIO_ROOT_PASSWORD: minioadmin
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
    interval: 30s
    timeout: 20s
    retries: 3
services:
  minio1:
    <<: *minio-common
    volumes:
      # 挂载配置文件和映射磁盘
      - /home/areswang/minio/config:/root/.minio
      - /mnt/disk1:/disk1
      - /mnt/disk2:/disk2
      - /mnt/disk3:/disk3
      - /mnt/disk4:/disk4
      - /mnt/disk5:/disk5
      - /mnt/disk6:/disk6
```

使用 `docker-compose up -d` 后， minio 就可以运行起来了。

![minio-web](/image/minio/minio-web.png)

## 如何恢复数据

假设你的磁盘坏了一到两块，例如用 `lsblk` 查看后发现如下:

```bash
sdc      8:32   0   2.7T  0 disk /mnt/disk1
sdd      8:48   0   2.7T  0 disk /mnt/disk2
sde      8:64   0   2.7T  0 disk
sdf      8:80   0   2.7T  0 disk /mnt/disk4
sdg      8:96   0   2.7T  0 disk /mnt/disk6
sdh      8:112  0   2.7T  0 disk /mnt/disk5
```

其中`/dev/sde`的磁盘无法被挂载，此时先不要担心， Minio 在仍然有一半(包括以上)的硬盘时，仍然是可以运转的。

- 如果还剩一半的硬盘一样，例如我有六块硬盘，目前有 4~6 块盘存活，那么整个 Minio 还是可以**读写**的
- 如果只剩三个硬盘了，那么 Minio 还是**可以读取，但是无法写入**

此时尝试更换一块硬盘，或者重新格式化该硬盘(确实是否是硬盘本身的问题后)，使用`mkfs.xfs` 给硬盘打上同样的标签，例如我这里丢失的是`/disk3`,那么参考命令就如下

```bash
mkfs.xfs /dev/sde -L DISK3 -f
```

格式化完后，使用`mount -a` 命令重新挂载一下硬盘，并且重启一下 Minio 即可，就恢复使用了。

## 另外需要准备的事情

1. 新建一个 Bucket 给 JuiceFS 使用，这里创建的 bucket 名字就是 juicefs
2. 在 Identity - Users 里创建一个`juicefs`的账户，并且创建一个`AccessKey` 和 `SecretKey`
3. 准备一个数据库， Redis/PostgreSQL/Mysql/Etcd 等等都可以，用于给 juicefs 存放元数据。可以同样跑在 Minio 的服务器上。

## 使用 JuiceFS

### 安装 JuiceFS

安装也比较简单，非 Windows 的系统可以用一键脚本安装：

```bash
curl -sSL https://d.juicefs.com/install | sh -
```

### 创建文件系统

我们需要一个数据库用于存放 JuiceFs 的元数据， 对象存储用于存放实际的数据

```bash
juicefs format \
    --storage minio \
    --bucket http://<minio-server>:9000/<bucket> \
    --access-key <your-key> \
    --secret-key <your-secret> \
    redis://:mypassword@<redis-server>:6379/1 \
    myjfs
```

**需要注意，其中 `S3` 存储和 `Redis` 数据库的地址，都应该写外部地址，而非 `127.0.0.1/localhost`**

否则在元数据引擎中，记录的 `S3` 地址仍然为 `localhost`, 这样其他设备就无法访问到 `S3` 存储了。

### 挂载 JuiceFS

#### Unix 系统

具体可以参考[启动时自动挂载 JuiceFS](https://www.juicefs.com/docs/zh/community/mount_juicefs_at_boot_time)

#### Windows 系统

**TODO**
