---
title: Centos7的mysql安装
date: 2020-11-09 13:29:47
categories: linux环境
tags: 
    - linux环境
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/centos.jpeg
---

#### 下载官方mysql源

```
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
```

#### 加载rpm源

```
rpm -ivh mysql-community-release-el7-5.noarch.rpm
```

<!--more-->

#### yum安装

```shell
yum install mysql mysql-devel mysql-server -y
```

#### 开启mysqlserver

```
systemctl start mysqld
//设置开启启动
systemctl enable mysqld
```

#### 设置mysql远程权限

```
--切换数据库
	use mysql;
--查看表
	show tables;
--查看表的数据
	select  host,user,password from user;
--插入权限数据
	grant all privileges on *.* to 'root'@'%' identified by '123' with grant option;
--删除本机的用户访问权限（可以执行也可以不执行）	
	delete from user where host!='%';
--刷新权限或者重启mysqld的服务
	service mysqld restart;--（重启mysql服务）
	flush privileges;--(刷新权限)	
```



