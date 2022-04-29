---
title: hexo github部署异常
date: 2020-11-17 09:49:32
categories: 建站
tags:
	--博客搭建
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hexo.jpg
---

#### 邮箱收到github构建异常

三个月前,我的gmail收到一封关于hexo在github上构建异常的邮箱

邮箱的主要内容如下:

The page build failed for the `master` branch with the following error:

The symbolic link `/blog_workspace` targets a file which does not exist within your site's repository.

<!-- more -->

刚刚搭建博客的小白一时不知道该从何查起,我的博客是国内走coding部署,国外走github部署的,

自己访问了一下blog测试了一下,国内可以访问,国外构建失败,

然后点进github提供的doc文件发现,github开发了自己的静态网站构建程序jeklly,

之后github 提供的pages服务都将使用jeklly,这就让人头大了

之前对hexo投入这么多,回头闷头一棍子,让我重新用jeklly开始构建,这不行



之后就一直先把这事情放着,毕竟本博客国外基本没有访客,

今天刚刚发现hexo官方网站早就已经给出了解决方法,将持续部署服务从github pages转交给travis CI

这个问题就可以完美解决,下面给出官网链接

https://hexo.io/zh-cn/docs/github-pages

按照官网一步一步做就可以,需要注意的是

**将 `.travis.yml` 推送到 repository 中。**

这句话,意思是通过hexo d命令而不是git push命令.