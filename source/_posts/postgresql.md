---
title: postgresql的搭建（linux7）以及powerdesigner远程连接(windows10)
date: 2019-12-28 21:14:32
categories: 数仓建模
tags:
   - 建模工具
   - 建模DB
cover_picture: http://picture.lemcoden.xyz/cover_picture/mapreduce.jpg
---



### 1.介绍

这篇文章主要分两个部分：
* postergresql的搭建
* powerdesigner远程连接postergtresql
读者可以根据自己的需求读取
<!-- more -->
### 2.postergresql的搭建
#### 安装
首先去官方网站下载安装包https://www.postgresql.org/download/
根据网站要求利用linux的yum命令安装，比如我下载是9.6版本我就按照官网给出的如下命令下载
```
yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install postgresql96
yum install postgresql96-server
```
#### 启动
等待下载完成，完成之后利用如下命令启动postgresql服务器
```
/usr/pgsql-9.6/bin/postgresql96-setup initdb //初始化数据库的命令千万别丢掉，否则启动会报错（log里面一般有PGS_DATA关键字）
systemctl enable postgresql-9.6
systemctl start postgresql-9.6
```
#### 为远程连接做准备
修改PostgreSql的客户端密码
```
sudo -u postgres psql \\使用psql客户端登陆
postgres=# ALTER USER postgres WITH PASSWORD '123456'; \\把密码修改为123456
postgres=# \q                \\退出客户端
```
设置postgre可以远程调用
```
cd /var/lib/pgsql/9.6/data 打开postgre配置文件夹
vim pg_hba.conf  \\添加允许访问IP
host all all 0.0.0.0/0 md5
vim postgresql.conf \\设置允许链接地址，'*'为允许所有连接
#listen_addresses = 'localhost' # what IP address(es) to listen on;
listen_addresses = '*'         # what IP address(es) to listen on;
```
PS：配置文件夹如果不是这个可以通过如下命令
```
[root@vm018centos ~]# yum list installed | grep postgres
postgresql96.x86_64                9.6.16-2PGDG.rhel7         @pgdg96           
postgresql96-libs.x86_64           9.6.16-2PGDG.rhel7         @pgdg96           
postgresql96-server.x86_64         9.6.16-2PGDG.rhel7         @pgdg96           
[root@vm018centos ~]# rpm -ql postgresql96-server.x86_64
```
查询文件安装目录，一般是在data文件夹下

记得关闭防火墙（划重点！！！！！）
### 3.powerdesigner远程连接postergtresql
下载psqlODBC 网址：http://www.postgresql.org/ftp/odbc/versions/msi/
PS：注意安装32位的对应版本的ODBC目前Powerdesiner只支持32位环境的安装（配置版本位数不对连接时会报Could not Initialize JavaVM!或者No suitable driver found for 错误）

下载安装后，配置psql的ODBC驱动
开始->控制面板-管理工具->数据源（odbc)->用户DSN->添加
把PostgreSQL ANSI和PostgreSQL Unicode两项添加到用户数据源

打开PowerDesiner
新建一个物理模型 （Physical Diagram）

配置ODBC步骤：
Database -> Configure Connection... -> ODBCMachine Data Sources -> PostgreSQL35W 配置ODBC连接的用户名密码服务器IP端口等信息

从数据库中更新
Database -> Update Model frome Database -> Current DBMS 选择 PostgreSQL 9x & Using a data source 设置登陆ID和密码 并连接 & Reverse engineer .... 打勾
点击确定连接更新完成
