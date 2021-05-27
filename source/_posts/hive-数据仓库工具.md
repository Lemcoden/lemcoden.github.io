---
title: hive 配置及命令备忘录
date: 2019-11-07 21:16:09
categories: hadoop生态
tags:
    - 数据仓库
    - 分布式
cover_picture: http://picture.lemcoden.xyz/cover_picture/hive.jpg
---

### 安装配置
下载
```
wget http://mirror.bit.edu.cn/apache/hive/hive-2.3.4/apache-hive-2.3.4-bin.tar.gz
wget https://mirrors.tuna.tsinghua.edu.cn/apache/hive/hive-2.3.5/apache-hive-2.3.5-bin.tar.gz
```

<!-- more -->
安装MYSQL
```
wget http://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
sudo yum -y install mysql57-community-release-el7-11.noarch.rpm
sudo yum install mysql-community-server
#启动服务
sudo systemctl start mysqld.service
#查看密码
grep "password" /var/log/mysqld.log
#登录 、改密 、数据库授权、创建数据库、创建用户、刷新 权限。修改的密码123456只为演示，简单密码无法设置
mysql -uroot -p
mysql>ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';
mysql>CREATE USER 'hive'@'%' IDENTIFIED BY '123456';
mysql>CREATE DATABASE hive;
mysql>GRANT ALL PRIVILEGES ON hive.* TO 'hive'@'%';
mysql>FLUSH PRIVILEGES;
mysql>EXIT;
#开机启动
sudo systemctl enable mysqld
#刷新
sudo systemctl daemon-reload
```
解压
```
tar -zxvf apache-hive-2.3.5-bin.tar.gz
#移动到安装目标文件夹：
sudo mkdir /opt/hive/
sudo chown -R hadoop.bigdata /opt/hive/
mv apache-hive-2.3.5-bin /opt/hive/
```
添加环境变量
```
sudo su root
echo '
# hive env -----------start
export HIVE_HOME=/opt/hive/apache-hive-2.3.5-bin
export PATH=$HIVE_HOME/bin:$PATH
# hive env -----------end
' >> /etc/profile
exit
# 返回hadoop用户
source /etc/profile
```
配置hive-site.xml
```

<property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
        <discription>数据库用户名</discription>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>123456</value>
        <discription>数据库密码</discription>
    </property>
   <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:mysql://vm018centos:3306/hive?characterEncoding=utf8&amp;useSSL=false</value>
        <discription>数据库连接地址</discription>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>com.mysql.jdbc.Driver</value>
        <discription>JDBC驱动</discription>
    </property>
	<property>
		<name>hive.exec.local.scratchdir</name>
		<value>/tmp/${user.name}</value>
		<description>Local scratch space for Hive jobs</description>
	</property>
	<property>
		<name>hive.downloaded.resources.dir</name>
		<value>/tmp/${user.name}_resources</value>
		<description>Temporary local directory for added resources in the remote file system.</description>
	</property>
		<!-- 这是hiveserver2 -->
	<property>
		<name>hive.server2.thrift.port</name>
     	<value>10000</value>
	</property>
    <property>
       	<name>hive.server2.thrift.bind.host</name>
       	<value>vm018centos</value>
    </property>
```
下载驱动：
```
wget https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.47.tar.gz
tar -zxvf mysql-connector-java-5.1.47.tar.gz
cp mysql-connector-java-5.1.47/mysql-connector-java-5.1.47-bin.jar $HIVE_HOME/lib
```
初始化
```
schematool -dbType mysql -initSchema
```

### 启动使用

启动hiveserver/hiveserver2
```
 $HIVE_HOME/bin/./hive --service  hiveserver2
```
默认thrift配置
```
hive.server2.thrift.min.worker.threads– 最小工作线程数，默认为5。

hive.server2.thrift.max.worker.threads – 最大工作线程数，默认为500。  

hive.server2.thrift.port– TCP 的监听端口，默认为10000。  

hive.server2.thrift.bind.host– TCP绑定的主机，默认为localhost。
```
启动客户端连接
```
	beeline -u jdbc:hive2://vm018centos:10000
```
### 窗口函数模板
