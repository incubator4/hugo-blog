---
title: "从普通Lumen转变成使用Roadruner"
date: 2020-10-28T15:58:57+08:00
draft: true
---

## 前言

在午休的时候看到了这么一篇内容[PHP 不会死 —— 我们如何使用 Golang 来阻止 PHP 走向衰亡](https://studygolang.com/articles/17639)

当时就很好奇，研究了一些发现，这其中提到了一个关于如何使用Go和PHP之间互相调度的框架[Goridge](https://github.com/spiral/goridge)

并且因此衍生出一个叫做[RoadRunner](https://github.com/spiral/roadrunner)的，由GO开发的PHP高性能服务器。相比传统的Nginx/Apache+PHP-FPM模式有一些区别。

[用 RoadRunner 加速 Laravel 应用](https://learnku.com/articles/13420/speed-up-laravel-application-with-roadrunner)
在这篇性能测评上，结果显示使用RoadRunner比起使用Nginx+PHP-FPM会更加高效

## 正文
代码可以在github仓库[lumen-roadrunner-daemon](https://github.com/Incubator4th/lumen-roadrunner-daemon)找到
### 新建laravel项目
```bash
composer create-project --prefer-dist laravel/lumen lumen-roadrunner-daemon ""
#Creating a "laravel/lumen" project at "./lumen-roadrunner-daemon"
```

经过一系列的composer包下载之后，我们的项目lumen-roadrunner-daemon就新建完了

### 安装RoadRunner

#### 安装composer包
`composer require spiral/roadrunner`来安装roadruner

如果出现memory错误的情况，按照[错误提示](https://getcomposer.org/doc/articles/troubleshooting.md#memory-limit-errors)来修改

例如，通过环境变量控制关闭内存检查`COMPOSER_MEMORY_LIMIT=-1 composer require spiral/roadrunner`

#### 获取二进制文件

二进制文件需要php gd库和php zip的库，使用`./vendor/bin/rr get-binary`可以在项目目录下得到一个名叫rr的roadruner二进制文件

当然，也可以从RoadRunner的github release中安装对应操作系统的二进制文件到系统目录，这样可以在任意路径使用

### 使用RoadRunner 运行laravel 应用

#### 已知问题

官方项目[roadrunner-laravel](https://github.com/spiral/roadrunner-laravel)中使用的方案有一些问题，在[issue6](https://github.com/spiral/roadrunner-laravel/issues/6)中提到，由于roadrunner-laravel接管了输出，导致echo 等函数都无法使用

#### 解决方案

参考[php-lumen-roadrunner](https://github.com/Erandelax/php-lumen-roadrunner)中的方案

然后在项目的目录下新建了一个rr.php文件来定义psr7
```php
<?php

require __DIR__ . "/vendor/autoload.php";

use Symfony\Bridge\PsrHttpMessage\Factory\DiactorosFactory;
use Symfony\Bridge\PsrHttpMessage\Factory\HttpFoundationFactory;

$relay = new Spiral\Goridge\StreamRelay(STDIN, STDOUT);
$psr7 = new Spiral\RoadRunner\PSR7Client(new Spiral\RoadRunner\Worker($relay));

$app = require_once __DIR__ . '/bootstrap/app.php';

while ($req = $psr7->acceptRequest()) {
	try {
		$httpFoundationFactory = new HttpFoundationFactory();
		$request = Illuminate\Http\Request::createFromBase($httpFoundationFactory->createRequest($req));
		
		$response = $app->dispatch($request);
		
		$psr7factory = new DiactorosFactory();
		$psr7response = $psr7factory->createResponse($response);
		$psr7->respond($psr7response);
	} catch (\Throwable $e) {
		$psr7->getWorker()->error((string)$e);
	}
}
```

.rr.yaml的配置如下，可以看到这里使用了rr.php来启动
```yaml
http:
  address:   0.0.0.0:8080
  maxRequest: 200
  uploads:
    forbid: [".php", ".exe", ".bat"]
  workers:
    command: "php rr.php"
    pool:
      numWorkers: 4
      maxJobs:  0
      allocateTimeout: 60
      destroyTimeout:  60
static:
  dir:   "public"
  forbid: [".php", ".htaccess"]
```

运行`./rr -c .rr.yaml serve -d`后会报错`Error: Class 'Symfony\Bridge\PsrHttpMessage\Factory\HttpFoundationFactory' not found`
这是因为少了依赖，安装依赖`composer require symfony/psr-http-message-bridge "^1.2"`

运行起来之后，通过网页访问8080或者curl访问

```bash
curl localhost:8080
#Lumen (5.8.12) (Laravel Components 5.8.*)%
```

说明已经可以用roadruner运行lumen应用了