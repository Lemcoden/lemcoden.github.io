---
title: hexo优化:github+coding双搭建，域名CNAME别称指向
date: 2020-05-20 13:17:20
categories: 建站
tags:
					- 博客搭建
cover_picture: http://picture.lemcoden.xyz/cover_picture/hexo.jpg
---
前情提要:
<a href="https://lemcoden.xyz/2020/01/05/hexo-github-%E6%90%AD%E5%BB%BA%E6%95%99%E7%A8%8B/">hexo + github 搭建教程</a>
<a href="https://lemcoden.xyz/2020/01/06/%E8%AE%B0%E5%BD%95%E4%B8%80%E6%AC%A1github-hexo-%E6%96%87%E4%BB%B6%E7%9A%84%E8%BF%81%E5%BE%99/">记录一次github + hexo 文件的迁徙</a>
### 前言
		填一下之前搭建博客的坑，之前发布了一篇搭建hexo的博客，有读者(无中生读者)反应，博客搭建完之后，网站访问很慢，的确，在这样的快节奏时代，超过5秒的网页大家都不想打开，所以笔者写了这篇关于博客的优化(感觉不能算作优化，只是填坑)。
<!-- more -->

### 追究起因
博客访问慢，追究其原因，主要是github的服务器在境外，域名解析的时候难免要绕几个圈子，那怎么办呢？~~让读者修改hosts文件~~，\~ε=ε=ε=(\~￣▽￣)\~，当然不会了，这种事当然是我们服务端解决。<br/>
好的回正题，我们可以利用域名解析CNAME，通过CNAME,我们把代码托管的服务器分为境内和境外，境内用coding托管平台的pages（静态网站服务），境外使用github平台的pages，这样我们在境内访问的时候，切到coding的服务器，访问会变得非常便捷。
### coding项目托管
其实境内的代码托管平台很多，有码云，阿里云，华为云,想挑战一下的可以试试这些代码平台，这里给出coding的解决方法，因为对于新手来说，coding提供的pages服务（帮助文档一看就懂）相对比较简单，适合个人建站。<br/>
#### 注册登录（觉得too easy，可跳）
打开浏览器，输入coding.net,回车访问<br/>
点击右上角注册<br/>
![coding主页](http://picture.lemcoden.xyz/blog_optimize/coding_regist.png)<br/>

![注册](http://picture.lemcoden.xyz/blog_optimize/coding_registe_step1.png)<br/>
还记得之前建站的博客名字吗？这次我们同样的，博客名字要和团队名称，登陆地址一模一样，便于部署。
接下来填名字邮箱什么的就不说了，按自己个人情况填就可以，最后邮箱验证一下ok，完成注册。
#### 设置免密登陆（可跳）
如果你想方便一点，不想每次进入coding都输入密码，每次上传代码都输入密码的话，我们可以设置ssh免密登陆。<br/>
具体操作：<br/>
打开dos或者终端命令行<br/>
windows系统进入C：/用户（也可能是user）/你的用户名/<br/>
linux系统进入：/home/你的用户名/<br/>
输入

	ssh-keygen -m PEM -t rsa -b 4096 -C 注册的邮箱地址

命令生成密钥
然后一路回车<br/>
之后你会发现该路径下有一个.ssh文件，进入，用文本编辑器打开id_rsa.pub,复制里面的所有内容<br/>
然后进入coding主页面，点击右上角个人设置→ SSH公钥 → 新增公钥<br/>
![coding主页](http://picture.lemcoden.xyz/blog_optimize/coding_person.png)
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_pub_id.png)
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_cipher.png)
公钥名称随便写，便于记忆就可以，公钥内容帮我们之前复制的id_rsa.pub的内容粘贴进去就可以。<br/>
自己定义一下有效期，点击添加，这样我们以后用注册过密钥的电脑登陆就不再需要密码了。<br/>
#### 免密部署（可跳）
<font color=HotPink>这里建议看完后面的项目建立之后再回来设置</font><br/>
免密部署和免密登陆很相似，首先我们在刚刚的.ssh文件夹中再次输入命令

	ssh-keygen -m PEM -t rsa -b 4096 -C 注册的邮箱地址


然后这一次不要一路回车，等出现下面的log
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/ssh_coding.png) <br/>
我们输入id_deploy,之后再一路回车，<br/>
我们会在.ssh文件夹新增了两个文件id_deploy还有id_deploy.pub,<br/>
老规矩，编辑器复制内容，进入coding控制台 → 全部项目 → 选中你建立的项目 → 代码仓库 → 设置 → 部署公钥 <br/>
按免密登陆的方式复制添加就可以。<br/>
#### 新建&部署项目
工作台 → 全部项目 → 新建项目
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_new_project.png)
这里需要注意，要选择DevOps项目，前两个没有pages服务的，新建了也没用，~~笔者曾栽入此坑~~
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_np_step1.png)
这里老规矩了，项目名称，仓库名称和github，博客名字一致，选git仓库，最后点击完成创建
项目创建好之后
我们进入项目管理界面，
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_np_step1.png)
进入代码仓库 → 设置
点击复制仓库链接（登录输入帐号密码的用https,如果是ssh免密的复制ssh），然后回到我们之前的hexo博客文件中
打开config.yml文件
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_np_step1.png)
将我们原来的部署设置添加一个coding项目，coding后面添加我们刚刚复制的仓库链接
然后再source文件新建两个文件，第一个CNAME文件，内容填你的域名比如lemcoden.xyz
第二个Staticfile文件，什么都不用填

之后就hexo部署玩起来

```
hexo g
hexo d
```
然后刷新一下coding的代码仓库，验证是否有更新。
#### 设置pages
还是项目管理界面，找到持续部署 → 静态网站，点击开通，对就这么简单。
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/coding_pages_url.jpg)
不过记得复制一下这个网站地址，等一下要用
### 域名解析
#### Godaddy的坑
关于上次hexo的搭建还有一个坑，那就是笔者推荐了Godaddy的域名，但是显然，官网推广做的很好，根本不需要推荐，毕业当时作为小萌新也是有那种“既然大家都在用，那一定很不错”的想法，然而，只能说<br/>
![coding个人设置](http://picture.lemcoden.xyz/blog_optimize/emoticon1.jpg)
官网访问特别慢，DNS解析做的也不是很好，CNAME和A记录死活配置不上去，这也就是为什么笔者当时使用是域名转址而不是CNAME别称的原因。<br/>
但是域名转址有很大的缺陷，即使是对用户来说，要是显式跳转吧，直接跳转到github的pages，地址栏上的github.io的后缀就很扎眼，如果是隐式跳转吧，进入某个具体的博文，地址栏也不会显示路径，想分享复制URL就很困难。<br/>
所以如果读者想尝试其他域名提供商，笔者推荐namecheap或者namesoil，来自某踩过Godaddy坑的前辈的经验<br/>
如果你已经在Godaddy注册了域名也没关系，Godaddy的DNS解析服务是可以转出的，<br/>
#### DNSPod解析
在这里笔者也选择同为腾讯的DNSPod作为解析服务商。<br/>
首先我们还需要最后在Godaddy走一趟,~~真的最后一次doge~~<br/>
进入官网 → 右上角登录 → 右上角菜单我的产品 → 点击你的域名旁边的DNS <br/>
![godaddy我的产品](http://picture.lemcoden.xyz/blog_optimize/godaddy_dns.jpgraw=true)
![godaddy Dns设置](http://picture.lemcoden.xyz/blog_optimize/godaddy_dns_server.jpg)
![godaddy DnsPod服务器](http://picture.lemcoden.xyz/blog_optimize/godaddy2dnspod.jpg)
到，域名服务器那里，点击更改<br/>
选择我将使用自己的域名服务器， <br/>
下面两个地址栏填入DNSPod的解析服务器地址，即<br/>
```
f1g1ns1.dnspod.net
f1g1ns2.dnspod.net
```
点击保存，好了现在我们的DNS解析服务就已经转到DNSPod上了<br/>
接下来去<a href="https://www.dnspod.cn/">DNSPod官网</a>
注册登陆就不用笔者说了吧\~\~,~~感觉这次写太长了，所以偷懒省略了(๑•̀ㅂ•́)و✧~~<br/>
注册登陆后，点击右上的管理控制台 → 选择DNS解析 → 我的域名 → 添加域名，将我们在Godaddy的域名输入<br/>
点击添加，添加之后如果状态是失败的话，也不要着急，godaddy那边轮询DNS可能需要十几分钟，我们先做下面的。<br/>
这里笔者重点挑出一个坑，就是点击域名之后在域名设置里面下面的功能设置<font color=#00FF00>一定，一定，一定要开启CNAME优化</font>（搜索引擎优化也可以加），否则添加解析记录的时候，你会找不到CNAME域名的类型<br/>
解析的最后一步，添加DNS解析记录。笔者先给出DNS记录，然后慢慢解释。<br/>
![DnsPod域名记录](http://picture.lemcoden.xyz/blog_optimize/dnspod_record.jpg)
<font color=HotPink>下面的解析记录，关于github的所有记录请先不要添加，等绑定coding域名时，申请完证书之后，再添加</font> <br/>
首先基本的4个CNAME记录类型的记录，<br/>
其中两个主机记录为@,两个主机记录为www。<br/>
&emsp;首先说@记录，一个指向我们github的pages地址，一个指向我们刚刚复制的coding的pages地址，<br/>
&emsp;然后www记录，一个指向我们的github记录的pages地址，一个指向我们刚刚复制的coding地址。<br/>
&emsp;&emsp;其中github的指向记录线路设为境外，coding的指向记录设为境内<br/>
&emsp;&emsp;如果出现提示线路必须有默认，建议把coding设置为默认（和图片有点出入，作者懒得改了）。<br/>
最后一个记录是github的证书服务器IP。
进入coding的静态网站项，点击右上角设置，
![coding绑定域名](http://picture.lemcoden.xyz/blog_optimize/coding_bind_domain.jpg)
绑定一下域名,绑定成功之后，coding会自动申请证书。等证书设置完成之后，再将github相关的解析记录添加。
最后两步，去gitthub 项目里的Settings页面找 github Pages选项，如果选项显示还没有绑定域名的话<br/>
![github设置](http://picture.lemcoden.xyz/blog_optimize/github_bind_domain.jpg)
在解析记录里添加一条github的证书服务器的记录，记录类型为A，记录内容为一下IP的任意一个（一项不行，换另一项）<br/>
```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```
