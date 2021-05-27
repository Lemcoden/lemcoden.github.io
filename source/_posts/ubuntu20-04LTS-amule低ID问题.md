---
title: 'ubuntu20.04LTS:amule低ID问题'
date: 2021-05-09 16:29:15
tags: linux客户端
cover_picture: http://picture.lemcoden.xyz/cover_picture/ubuntu.jpg
---
### 起因

作为ubuntu开源爱好者,迅雷那样的流氓软件当然能不使用就不使用

那么,我们使用什么开源软件的进行下载呢?

首先我们看一下都有哪些下载协议

**第一种thunder://QUFtYWduZXQ6P3h0PXVybjpidGloOjAzRjYxODA0RTFFQzFCMTQyQzU0RERCNUQ3QjhCRUQ2OUIxREY2MzhaWg==**

不得不说这完全是迅雷自己yy出来的一种协议,其实就是其他协议中包了个壳子,只要将协议后面的等号去掉,将中间的一堆乱码,base64解码一下就可以出来,比如上面的协议解码出来是这样子

```bash
//在unbuntu中通过base64命令,将代码解码,解码出来的数据去掉开头的AA和结尾的ZZ就是真正的下载url
lemcoden@unbuntu:~$ echo "QUFtYWduZXQ6P3h0PXVybjpidGloOjAzRjYxODA0RTFFQzFCMTQyQzU0RERCNUQ3QjhCRUQ2OUIxREY2MzhaWg==" | base64 -d 
AAmagnet:?xt=urn:btih:03F61804E1EC1B142C54DDB5D7B8BED69B1DF638ZZ
```

解码出来如果是http就用浏览器直接下载,如果不是,像上面这种的BT种子协议,我们用trasmission

**第二种**

**magnet:?xt=urn:btih:03F61804E1EC1B142C54DDB5D7B8BED69B1DF638**

这是种子协议,我们一般是用transmission下载,不过一开始用绝对下载速度很慢,因为BT的种子协议是基于分享的,也就是说,我下载文件的同时,将自己作为在这个下载文件的服务器,提供给他人下载,所以我们会经常看到,BT种子协议在下载时,还会产生很大的上传流量,不过我们贡献的上传流量不是白白贡献的,协议会根据我们上传的流量,提高我们下载的优先级.所以会出现一开始下载很慢,之后速度就开始起飞

什么?你说迅雷为啥下载那么快?

迅雷有自己的服务器,我们请求下载,我们客户端会在迅雷的服务器首先查询文件,有时候不用走BT协议,不需要自己上传,直接从迅雷服务器拉下来,你说快不快?如果服务器没有,服务器就作为第二个客户端和你一起下载,就像用多线程.

当然如果觉得transmission颜值差的,还可以试试**motrix**

**第三种**

**ftp://10.8.153.10:2121/dysms_python/**

ftp协议,这没什么说的,浏览器,ftp,wget命令都可以直接下载

**第四种**

**ed2k://|file|Doctor.Who.2005.S07E05.1080p.BluRay.x264-BiA.mkv|3521946964|9C15418762B1A492712FE390F0736F49|h=RSLPVYLUGGEN5472VPVABZXTVJW6CFWF|/**

ed2k的协议,看似不常用的协议,但是遇到了还真就很难找到除了迅雷的其他软件,找到了也很难用,比如edonkey,emule,amule,对,就是现在的标题,amule的低ID问题

### 进入正题

首先说amule的界面没有我们想像的那么简单,即傻瓜式的一键下载,因为ed2k的协议也是基于共享的,即会把自己的电脑当作文件服务器上传文件数据流,但是比较坑的点在于,我们需要能够被别人访问的公网IP

首先我们先从amule的界面下手,

![http://picture.lemcoden.xyz/ubuntu/amule.png](http://picture.lemcoden.xyz/ubuntu/amule.png)

如上图的界面,amule需要连接特定的下载服务器,我们可以通过左上角的播放键查询服务器列表,然后双击对应服务器进行连接,一般选择延迟低并且连接人数多的

但是这就产生了一个问题,往往你的界面左下角会出现

警告:你收到一个低ID的字样.

如果是低ID的话,下载速度是很慢的,因为你没有办法被别人的服务器直连,而是通过公共的服务器进行中转.

首先,我们需要公网IP,即别人可以对你的电脑进行直接访问,这时候你是否意识到,唉?原来我的电脑没办法被别人直接访问?

对,事实确实如此,因为IPV4地址资源的短缺,再加上网络提供商为了维护便利,他们一般是提供路由过的内网IP,如果是这种就需要给运营商打电话了,得申请自己的公网IP

如果你有一个公网IP,也会出现低ID的问题,还需要在光猫设置 端口映射,DMZ主机或者upnp(3选1),然而博主是最倒霉的,光猫屏蔽了超级管理员界面,这些东西我在 192.168.1.1的网页上面什么也看不到

还有一个办法是设置桥接模式,打电话给运营商客服,让他们转换成桥接模式,将光猫的功能桥接到路由器上,通过路由器设置这些功能.