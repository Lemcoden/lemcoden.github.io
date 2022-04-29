---
title: 'blog优化:图床选择&图片加水印&一些问题的解决'
date: 2020-06-28 09:53:16
categories: 建站
tags:
  - 博客搭建
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hexo.jpg
---
前情提要:
<a href="https://lemcoden.xyz/2020/05/20/hexo优化-github-coding双搭建，域名CNAME别称指向/">hexo优化:github+coding双搭建，域名CNAME别称指向</a>

### 关于域名备案

首先向各位读者道歉,之前向大家推荐了Godaddy的域名注册,笔者发现注册完成之后并不是非常好用,官网难以打开,客服反映慢,并且也不提供备案服务

如果大家像笔者之前的那样注册了Godady的域名,请直接去阿里&腾讯云社区,搜索域名转入,进行相关操作,<font color=00ff00>域名转入需要多交一年的域名租赁费用</font>

如果申请国内阿里,腾讯云的,可以直接去备案,<font color=00ff00>备案需要有域名提供商的云服务器,并且需要填写身份信息,备案申请,快的话一个星期才能申请下来</font>

### 关于图床

<!--more-->

#### 怎么加入图片?

关于怎么在hexo框架中加入图片,百度肯定有很多方法,笔者也尝试过,比如

- 直接加到github的库当中,然后通过链接引用,但是这样速度很慢,多次打开都是图片坏掉的小图标
- 使用*hexo*-asset-*image*,作为非nodejs的程序员,安装之后,引用图片并没有显示,并且中间还报了各种依赖异常,本人不会解决,所以直接跳过
- 踩坑之后笔者决定选择用云存储做图床,考虑到成本问题选择七牛云,完全免费

#### 七牛云

关于七牛云的注册,登录,以及申请对象存储,这里笔者不再多赘述,看着官方文档说明都可以做到,这里主要聊一聊申请过程中需要注意的问题

* 千万不要使用顶级域名绑定，可以在DNSpod域名解析那里添加一个子域名，比如这个

  

![picture_sub_domain](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/blog_optimize/picture_sub_domain.png)

* 上传图片之前记得添加前缀，多个路径用/隔开

![pic_path](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/blog_optimize/pic_path.png)

* 多图上传推荐用上传工具PicGo

####  PicGo的linux安装方法

<a href="https://github.com/Molunerfinn/PicGo">PicGo的github链接</a>

windows和mac直接在release里面下载相应的exe和dmg就可以

linux推荐下载appImage后缀的安装包

下载完成后,操作如下

```
cp PicGo-2.3.0-beta.3.AppImage /usr/bin/PicGo
chmod +x /usr/bin/PicGo
PicGo
```

然后直接命令输入PicGo运行就可以了

如果出现如下异常

```
xclip not found
```

控制台输入

```
sudo apt install xclip -y
```

安装xclip即可

这里放一个PicGo的配置参考



![conf_pic_go](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/blog_optimize/conf_pic_go.png)

存储区域华南,华北那些在官方文档有对应的参考映射值

<a href="https://picgo.github.io/PicGo-Doc/zh/guide/config.html#%E4%B8%83%E7%89%9B%E5%9B%BE%E5%BA%8A">官方配置指南</a>

#### 关于图片加水印

为了防止别人盗图,笔者特意写了一个加水印的脚本,逻辑很简单的一个shell脚本,基于image magic库对图片进行编辑,下面放出地址

https://github.com/Lemcoden/blog.tools