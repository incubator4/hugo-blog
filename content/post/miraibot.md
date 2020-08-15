---
title: 关于mraiBot的一点小想法
date: 2020-06-12 17:08:53
toc: true
tags:
  - kotlin
  - java
---


## 路由的解析
在使用http框架的时候，不可避免会遇到路由。每当发起一个http请求的时候，服务器会把请求的路由传入已注册的handle，当匹配时发生响应。

研究路由的具体实现形式，可以简单的认为是hashmap的实现形式，如下图
```
/
├── /a
├── /b
│   ├── /x
│   └── /y
└── /c
    └── /z
```

通过 /b/y 路径就能解析到对应的handle

## 系统命令

列举几个命令
```bash
~ ls -a [dir]
~ docker image inspect [image]
~ find [dir] -type f -name "*.tar"
```
从系统命令的哲学中可以发现，每个命令有许多子选项和子命令，每个参数之间通过空格区分，加入一系列的功能性参数达到一定的效果

## 关于MiraiBot

对比到目前的MiraiBot上，通常的命令形式都是以
function param1 param2 / function function2 param 形式实现的，这和路由以及命令的设计上具有高度的耦合性。

由于目前的插件命令解析都是通过每个插件本身完成的，就可能会遇到以下问题

- 参数冲突或者高度相似 pluginA: /fun command pluginB /func command

- 参数规范不同 /help #help !help ?help

- 命令参数没有统一的管理
等

## 设想改进

目前的console 加载插件对jar的部分是做完全透明的，指完全由插件本身解析，根据加载先后解析命令。因此提出设想，统一插件的功能性路由，使用console的命令分隔进行解析，加载插件对插件树进行挂载。

假设当前console有以下结构
```
console
├── pluginA
└── pluginB
     ├── command1
      └── command2
```
此时有一个 新的插件pluginC，我们希望把插件加入console的根节点下
树形结构就如图下所示
```
console
├── pluginA
├── pluginB
│   ├── command1
│   └── command2
└── pluginC
    └── command
```
此时 插件A的作者开发了A插件一个A插件的子插件 α ，并且只有在配合A插件使用时才会生效，于是我们可以把插件α挂载到A目录下
```
console
├── pluginA
│   └── plugin α
│          └── command
├── pluginB
│   ├── command1
│   └── command2
└── pluginC
    └── command
```
## 技术实现方案

### 插件加载

注解
```kotlin
@Plugin(path="a")
class PluginA() {
    
}
```
map加载
```kotlin
this.javaClass.kotlin.declaredFunctions.forEach {
    val annotation = it.findAnnotation<Annotaion>()
    if (一些判断) {
        console.plugin.map[path] = PluginA()
    }
}
```


### 个人想法
第一反应miraibot是一个非常好的qqbot框架，美中不足之处是，虽然它有插件库，但是插件库并没有像 类似搜狗词库，创意工坊类似的统一标准的插件订阅，使得bot就能增加新的功能，并且也能够统一插件的规范形式。虽然这件事并不是我说了算，但是希望能看到miraibot 的插件库能够变更加丰富和统一 （订阅插件或者导入jar的形式来加载更多的模块功能）