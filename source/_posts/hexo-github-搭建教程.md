---
title: hexo + github 搭建教程
date: 2020-01-05 15:42:44
categories: 建站
tags:
	--博客搭建
cover_picture: http://picture.lemcoden.xyz/cover_picture/hexo.jpg
---
### 本篇博客分为三部分
* github 账号注册，创建库，本地链接远程库
* hexo 的安装，主题以及博文的部署
* 域名的注册，设置转发
<!-- more -->
### 一、github 方面
#### github账号的注册
官网 https://github.com/
进入官网，就有注册页面
![官网示意](http://picture.lemcoden.xyz/github_register.png)
填完信息后点击注册，验证邮箱
#### 创建库
注册成功后，登陆到个人主页
点击头像，进入 Your repositories
![你的类库](http://picture.lemcoden.xyz/your_repositories.png)

进入 repositories 页面点击 New 按钮新建库
![新建库](http://picture.lemcoden.xyz/respository_new.png)
按要求新建库，注意库名一定是你的github用户名.github.io 否则可能别人访问会报页面404
![新将库要求](http://picture.lemcoden.xyz/new_respository.png)

#### 本地链接远程库
首先需要下载git工具，下载地址如下
https://git-scm.com/downloads
请根据自己的系统以及系统位数选择下载安装包

下载安装完成之后，去任意自己喜欢的磁盘目录新建一个<font color=Blue>博客文件夹</font>
比如笔者在F盘下面新建了个文件夹lemcoden.xyz\Lemcoden.github.io
然后在文件下右键点击Git Bash Here 选项
进入命令行窗口
![命令行窗口](http://picture.lemcoden.xyz/gitbash_example.png)
进入之后输入如下命令，设置登陆github的账号
```
git config --global user.name "这个地方写名字"
git config --global user.email "这个地方写邮箱"
```
然后按照github新建的库的命令提示依次输入命令（记住这里的git clone 命令后面的网址，后面要用到）
![建立远程库链接](http://picture.lemcoden.xyz/github_remote.png)
这样github的远程库链接就建立完成了

### 二、hexo方面
#### npm的安装
hexo需要npm作为包管理工具来下载安装，而npm是包含在node.js文件目录里的，因此我们先下载node.js
https://nodejs.org/en/
根据系统和系统位数下载安装包
安装除了自定义安装目录之外一路next就可以
安装完成后 在cmd命令中，echo %PATH% 一下
看node.js的目录是否包含在打印的字符中
如果没有，请右击我的电脑 -> 高级系统设置 -> 环境变量 -> 在系统变量的PATH变量的值后面追加 :你的node.js安装路径
![node.js的path](http://picture.lemcoden.xyz/node_js_path.png)

#### 利用npm安装hexo
打开cmd，将当前目录切换到<font color=Blue>博客文件夹</font>
切换之后输入如下命令下载hexo基础、客户端以及git部署插件
```
npm install hexo --save
npm install hexo-cli -g
npm install hexo-deployer-git --save
```
#### hexo初始化及其配置
hexo下载完成后，新建个文件夹，将当前<font color=Blue>博客文件夹</font>中的文件放入到新建文件夹中（因为hexo init 命令要求文件夹为空），执行如下命令
```
hexo init  
npm install
```
执行完成后，将新建文件夹的东西移动到原来<font color=Blue>博客文件夹</font>中。

修改<font color=Blue>博客文件夹</font>中的config.yml文件
修改如下地方
```
url: https://Lemcoden.github.io  //此为博客的地址
root: /    //此为博客地址下的根目录，因为这个站点不需要运行其他应用所以我把博客根目录直接写为/

...

deploy:
  type: git
  repo: https://github.com/Longzuzero/Lemcoden.github.io.git \\这里替换为之前使用 git clone 命令时的地址
  branch: master
```
这样子，hexo的配置就基本完成了
#### hexo主题替换以及博文写作
我们在<font color=Blue>博客文件夹</font>中，直接打开Git Bash,输入
```
hexo s
```
 命令，就可以通过localhost:4000 访问我们新搭建的博客了，但是新搭建的博客的默认主题比较简陋，我们可以在https://hexo.io/themes 选择自己喜欢的主题，在<font color=Blue>博客文件夹</font>的themes目录下运行
```
	git clone \\主题github页面要clone的地址
```
下载相应的主题并在<font color=Blue>博客文件夹</font>中的config.yml中配置theme变量来切换主题

我们可以通过
```
	hexo new "博文标题"
```
来新建一个博文，他会在<font color=Blue>博客文件夹</font>的soure/_post目录中新建个md文件，我们使用markdown语法来编辑即可
下面给出样例
```
---
title: 如何用hexo命令上传博客
date: 2019-12-28 21:14:32
categories: 博客
tags:
    - 博客分享
cover_picture: http://picture.lemcoden.xyz/cover_picture/logo.jpg
---
1.在个人博客文件夹的/source/_post目录里添加新的md文件，编写格式如下
![编写格式](https://raw.githubusercontent.com/LongZuZreo/lemcoden-images/master/hexo-update.jpg)
<!-- more -->
2.切换到个人博客的文件夹输入如下命令
```
```
hexo clean
hexo g
hexo d
```
```
文章就完整上传了
```
PS:more标签用来截断博文信息，more标签上面的信息会会直接显示在博客主页的post(对于android开发者来说叫Item更适当)当中
个人博客的上传参考如下
https://longzuzreo.github.io/Lemcoden.github.io/2019/12/28/hexo-s-blog-update/

### 三、域名的注册、转发

```
PS:这是博主在之后添加的,如果你需要注册域名请直接去我国的阿里云和腾讯云申请,因为只有国内域名管理商提供备案,之后笔者也被坑到
```

博文上传后别人可以通过   你的github用户名.github.io  访问你的博客

但是作为一名高逼格的博主，没有域名怎么可以，购买域名推荐Godaddy的网站
[Godaddy官网](https://sg.godaddy.com/zh/offers/domains/godaddycom?isc=gennbacn07&countryview=1&currencyType=CNY&utm_source=baidu&utm_medium=cpc&utm_term=Title&utm_campaign=zh%2Dcn%5Fcorp%2Dcore%5Fsem%5Fb%5Fbz%5Fx%5F001&utm_content=Brandzone%20PC&gclid=CMCSqcnD7OYCFcuWvAod_8wITg&gclsrc=ds)
在里面注册账号，申请一个和自己博客名字一样的域名，一开始不需要投入太多，比如说博主申请带lemcoden名字的域名，就搜索lemcoden，然后看到lemcoden.xyz的域名最便宜，第一年只需要八块钱，然后就买了这个域名
购买域名后，点击管理域名，进入DNS管理中，最下面有个转址选项，
![转址](http://picture.lemcoden.xyz/other_address.png)
进入，输入转址地址 你的github账户名.github.io,别人就可以直接通过你购买的域名直接访问你的博客了