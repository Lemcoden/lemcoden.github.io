---
title: 'hexo升级,travis ci失效的问题解决'
date: 2021-05-29 21:13:14
categories: 建站
tags:
	- 博客搭建
cover_picture: http://picture.lemcoden.xyz/cover_picture/hexo.jpg
---

### 问题陈述

前两天准备更新一篇源码阅读相关的博客,但是使用hexo d部署到github上面之后页面死活不更新

详细查看后发现,之前看hexo官网的[中文文档](https://hexo.io/zh-cn/docs/github-pages),所使用持续集成功能所托管的网站,travis-ci.org网站搬迁到travis-ci.com并且集成服务也做了一些修改,更加的定制化.

不想看中间流程的同学可以直接进入到最后一个标题

### 尝试解决问题

我尝试在新的travis-ci.com上托管持续集成的功能,发现会发生很多的错误,并且新的持续集成功能定制化的功能很多,这导致我需要一步一步把travics-ci的官方文档看一边,才知道哪些流程出错了,哪些定制化开发流程需要重新配置.

但是,对于我一个node.js一点都不懂的java工程师而言,这样的学习成本很高,并且程序员都比较繁忙,很难抽出空来再去学习本专业无关的事.(仅指nodejs语言,非集成部署方式)

<!--more-->

这让我陷入了矛盾当中.

### 无脑重新部署

在定位问题的时候,我并不是立刻就找到问题所在的,而是不断的去做某些毁灭性的重启尝试(包括把npm和hexo卸载,重新安装,并升级到最新版,把不再维护的miho主题切换到热门的next主题),并重新开了一遍官方的技术文档

### 柳暗花明又一村

当我进行毁灭性重建的时候,不小心将所看的官方文档切换到英文版,以我英文十级~~(并不)~~的水平立刻发现了不对劲,首先抛开翻译问题,官方文档的中英文排版就不一样

![英文版](http://picture.lemcoden.xyz/blog_optimize/hexo_doc_en.png)

![中文版](http://picture.lemcoden.xyz/blog_optimize/hexo_doc_zh.png)

细细读了一下英文版,发现英文版直接使用的github自带的持续集成功能(可能是新出的),大概率官方忘了同步中文文档所导致的.

### 问题的解决方案

很简单,只要按照官方[英文文档](https://hexo.io/docs/github-pages.html),或者去阅读github的[nodejs持续集成](https://docs.github.com/cn/actions/guides/building-and-testing-nodejs)文档重新部署一遍就可以

