---
title: 玩转ubuntu 〇壹
date: 2020-08-13 20:00:37
categories: linux
tags: linux客户端
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/unbuntu.jpg
---

#### 终端 => 文件管理器

在终端输入,nautilus(中文直译为鹦鹉螺,是ubuntu默认文件管理器的名字,戏剧性的是笔者玩的一款游戏terraria,里面的某个boss就是nautilus,所以就顺带记住了)

```
nautilus ./
```

#### pc与手机链接(GSConnect方式)

主要是因为linux版QQ都是bug,linux也没有微信所以只能通过GSConnect链接手机

来相互传送文件.

<!--more-->

**pc端:**

打开浏览器

地址栏输入

```
https://extensions.gnome.org/
```

点击Extensions,搜索GSConnector

查看当前shell版本(可跳过)

```
bash --version
```

点击Install 询问是否下载安装,点击确定

安装完成后,点击右上角弹出系统菜单,

系统菜单里看到有个移动设备标识

**移动端:**

下载<font color='#00ff00'>KDEconnect</font>

**android**推荐去play商店下载,必须安装google四件套,或者F-droid(有这个选项但没有试过)

如果是android开发人员还可以直接去github下载<a href='https://github.com/KDE/kdeconnect-android'>源码</a>编译安装



**ios**这个不应说了就一个appStore,直接搜索安装就可以

安装完成之后,打开APP会看到KDE会自动搜索附近的电脑,

点击链接,电脑上确认密钥,之后系统菜单的移动设备打开会显示出传输选项.

效果图:

![桌面系统菜单](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/gsconnect.png)

![手机kde](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/phone_kde.jpg)

#### 安装微信

电脑可以没有QQ,但是不能没有微信

可以通过wine模拟器的方式安装windows版微信

通过wget命令下载wine,当然如果C语言好的话,可以去官网下载源码编译安装

也可以添加官网源,下载最新版,不过笔者不推荐,通过ppa下载官方包,非常的慢,没有下载下来的基本.

```
sudo apt install wine-stable
```

下载安装完成之后,去下载微信的安装包

通过命令

```
wine wechat.exe
```

方式启动微信

如果出现输入框不显示的问题输入如下命令

```
winetricks riched20
```

重启之后,重新打开即可

还有可能出现

#### 动态壁纸软件

推荐软件komorebi

<a href='https://github.com/iKurum/komorebi'>github地址</a>

通过阅读下面说明就可以轻松下载安装

支持视频格式动态壁纸,自定义时钟(视频壁纸平常可能会占些cpu)

[动态壁纸效果]: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/linux/komorebi.gif

