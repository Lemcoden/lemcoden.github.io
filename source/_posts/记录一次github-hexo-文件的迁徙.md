---
title: 记录一次github + hexo 文件的迁徙
date: 2020-01-06 21:57:35
categories: 建站
tags:
    - 博客搭建
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hexo.jpg
---
### 起因
事情是这样子的，我很早之前注册的名为longzuzero的github账号，当时名字是随便想，用《龙族》小说名的汉语拼音加上英文的零，当时n年后，我准备开始写属于自己的技术博客时，才发现，这个名字没有任何意义，所以建立博客之初我把名字定义为
<font color=#FFA500 size=3 >Lemcoden</font>
<!-- more -->
以米津玄师的《Lemon》加上程序员经常提到的code的并集，以独特的方式易懂表达程序，这个就是lemcoden的寓意
### 然而.........
当我直接用lemcoden.github.io命名github项目并且使用hexo搭建完博客，并且添加完域名转址之后，发现
我的博客只能以lemcoden.xyz访问，前面增加www前缀或者http协议名就会404。
原因应该是我的项目命名 lemcoden.github.io 与 我的github用户名 longzuzero 不同
所以，我重新注册了账号并做了代码迁徙，中间踩过不少坑，特此记录下来，以供大家参考
### 过程记录
关于github，如果注册新建库名就不多缀述，注册完新建项目，所以我的项目名如下
![新项目名](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/github_blog_name.png)
首先点击项目下方的ADD README.md 选项
为什么？
因为如果不通过自己的账号新建README.md文件，github不会把你的项目作为个人主页，添加到域名当中，
简单直接的说就是你无法通过 你的 用户名.github.io 在浏览器中访问
之后在本地的博客文件夹当中开启Git Bash
输入如下命令重新修改博客文件对应的远程链接以及用户名密码

```
git remote remove origin \\之前的远程库链接
git remote add origin \\当前远程仓库clone的地址
git config --global --reset user.name
git config --global --reset user.email  \\两条命令的意思是清除用户名邮箱
git config --global user.name \\新的github账户用户名
git config --global user.email \\新的github邮箱名
```
然后修改config.yml文件中的url，root以及git字段·
最后输入hexo命令 重新上传到新的代码仓库地址

```
hexo clean
hexo g
hexo d
```
最后修改一下域名的转址就可以了。
