---
title: hadoop集群HA高可用配置总结
date: 2020-08-19 16:27:16
tags:
    - hadoop生态
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hdfs.jpg
---
### 基础设施
* 网卡静态IP
```
ifconfig 查看网卡信息
vim /etc/udev/rules.d/70-persistent-ipoib.rules
              ACTION=="add", SUBSYSTEM=="net", DRIVERS=="?*", ATTR{type}=="32", ATTR{address}=="?*00:02:c9:03:00:31:78:f2", NAME="网卡名"
vim /etc/sysconfig/network-scripts/ifcfg-网卡名
POXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static  //设置静态IP
DEFROUTE=yes
NAME=enp0s3
UUID=290c55a8-1b88-4d99-b741-dcfe455f5c2c
DEVICE=enp0s3
ONBOOT=yes
IPADDR=192.168.0.101  //一般本地IP最后依次增加
NETMASK=255.255.255.0
GATWAY=192.168.0.1 //同一集群必须同一网关
```
* 设置hosts<!--more-->
```
vim /etc/hosts
192.168.0.101 hadoop01
192.168.0.101 hadoop02
```
* 关闭防火墙<br/>
```
Centos6.x
service iptables stop
service iptables status
chkconfig iptables off
Centos7.x
systemctl stop firewalld.service
systemctl status firewalld.service
systemctl disable firewalld.service
```
* 关闭 selinux
```
vi /etc/selinux/config
SELINUX=disabled
```
* 作时间同步
```
yum install ntp  -y
vi /etc/ntp.conf
主节点
          注释掉其他server
          server ntp1.aliyun.com
          server 127.127.1.0
          fudge 127.127.1.0 stratum 10
 从节点
          server 192.168.0.101
从节点设置crontab同步
vim /etc/crontab
10 20 * * * /usr/sbin/ntpdate -u 192.168.0.101
systemctl start ntpd
systemctl enable ntpd
```
* 安装JDK
```
rpm -i   jdk-8u181-linux-x64.rpm
		*有一些软件只认：/usr/java/default
vi /etc/profile     
	  export  JAVA_HOME=/usr/java/default
		export PATH=$PATH:$JAVA_HOME/bin
source /etc/profile   |  .    /etc/profile

```
* 免密登陆
```
ssh-keygen -t rsa  //一路回车
ssh-copy-id 其他节点
```
### 集群安装配置
```
tar -zxvf tar包 -C 目录
```
#### java配置
```
rpm -i   jdk-8u181-linux-x64.rpm
		*有一些软件只认：/usr/java/default
vi /etc/profile     
		export  JAVA_HOME=/usr/java/default
		export PATH=$PATH:$JAVA_HOME/bin
```


#### hadooop 配置

|       |NN	|NN	 |JN	|ZKFC|	ZK	|DN|	RM|	NM |
| ----- | ---- | ---- | ----| ---- | ---- | ---- | ---- | ---- |
|node01	| * |    | *  | *  |      |  |    |     |
|node02	|	  |  * | *  | *  |   *  | *|    |  *  |
|node03	|		|		 | *	| 	 |   *  | *|  * |  *  |
|node04	|		|    |    |    |   *  | *|  * |  *  |

hadoop配置的七个文件:<br/>
core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml <br/>
hadoop-env.sh mapred-env.sh slaves <br/>
core-site.xml
```
<property>
		  <name>fs.defaultFS</name>
		  <value>hdfs://mycluster</value>
		</property>

		 <property>
		   <name>ha.zookeeper.quorum</name>
		   <value>node02:2181,node03:2181,node04:2181</value>
		 </property>
```
hdfs-site.xml
```
# 以下是  一对多，逻辑到物理节点的映射
      <property>
				<name>dfs.replication</name>
				<value>1</value>
			</property>
			<property>
				<name>dfs.namenode.name.dir</name>
				<value>/var/bigdata/hadoop/local/dfs/name</value>
			</property>
			<property>
				<name>dfs.datanode.data.dir</name>
				<value>/var/bigdata/hadoop/local/dfs/data</value>
			</property>

		<property>
		  <name>dfs.nameservices</name>
		  <value>mycluster</value>
		</property>
		<property>
		  <name>dfs.ha.namenodes.mycluster</name>
		  <value>nn1,nn2</value>
		</property>
		<property>
		  <name>dfs.namenode.rpc-address.mycluster.nn1</name>
		  <value>node01:8020</value>
		</property>
		<property>
		  <name>dfs.namenode.rpc-address.mycluster.nn2</name>
		  <value>node02:8020</value>
		</property>
		<property>
		  <name>dfs.namenode.http-address.mycluster.nn1</name>
		  <value>node01:50070</value>
		</property>
		<property>
		  <name>dfs.namenode.http-address.mycluster.nn2</name>
		  <value>node02:50070</value>
		</property>

		#以下是JN在哪里启动，数据存那个磁盘
		<property>
		  <name>dfs.namenode.shared.edits.dir</name>
		  <value>qjournal://node01:8485;node02:8485;node03:8485/mycluster</value>
		</property>
		<property>
		  <name>dfs.journalnode.edits.dir</name>
		  <value>/var/bigdata/hadoop/ha/dfs/jn</value>
		</property>

		#HA角色切换的代理类和实现方法，我们用的ssh免密
		<property>
		  <name>dfs.client.failover.proxy.provider.mycluster</name>
		  <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
		</property>
		<property>
		  <name>dfs.ha.fencing.methods</name>
		  <value>sshfence</value>
		</property>
		<property>
		  <name>dfs.ha.fencing.ssh.private-key-files</name>
		  <value>/root/.ssh/id_dsa</value>
		</property>

		#开启自动化： 启动zkfc
		 <property>
		   <name>dfs.ha.automatic-failover.enabled</name>
		   <value>true</value>
		 </property>
```
mapred-site.xml
```
<property>
     <name>mapreduce.framework.name</name>
     <value>yarn</value>
</property>
```
yarn-site.xml
```
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
      </property>

   <property>
     <name>yarn.resourcemanager.ha.enabled</name>
     <value>true</value>
   </property>
   <property>
     <name>yarn.resourcemanager.zk-address</name>
     <value>node02:2181,node03:2181,node04:2181</value>
   </property>

   <property>
     <name>yarn.resourcemanager.cluster-id</name>
     <value>lemcoden_yarn_cluster</value>
   </property>

   <property>
     <name>yarn.resourcemanager.ha.rm-ids</name>
     <value>rm1,rm2</value>
   </property>
   <property>
     <name>yarn.resourcemanager.hostname.rm1</name>
     <value>node03</value>
   </property>
   <property>
     <name>yarn.resourcemanager.hostname.rm2</name>
     <value>node04</value>
   </property>
```
hadoop-env.sh
```
export JAVA_HOME=/usr/java/default
```
mapred-env.sh
```
export JAVA_HOME=/usr/java/default
```
slaves
```
node02
node03
node04
```
设置环境变量 <br/>
```
vi /etc/profile
		export  JAVA_HOME=/usr/java/default
		export HADOOP_HOME=/opt/bigdata/hadoop-2.6.5
		export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
source /etc/profile
```
软件包分发:
```
cd /opt
			scp -r ./bigdata/  node02:`pwd`
			scp -r ./bigdata/  node03:`pwd`
			scp -r ./bigdata/  node04:`pwd`
```

#### zookeeper配置:
cp zoo_sanmple.cfg zoo.cfg <br/>
zoo.cfg
```
      datadir=/var/bigdata/hadoop/zk
			server.1=node02:2888:3888
			server.2=node03:2888:3888
			server.3=node04:2888:3888
```
mkdir /var/bigdata/hadoop/zk
配置环境变量:
node02
```
vi /etc/profile
				export ZOOKEEPER_HOME=/opt/bigdata/zookeeper-3.4.6
				export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin
. /etc/profile
```
分发软件包:
```
scp -r ./zookeeper-3.4.6  node03:`pwd`
scp -r ./zookeeper-3.4.6  node04:`pwd`
```
设置myid:
```
node03:
			mkdir /var/bigdata/hadoop/zk
			echo 2 >  /var/bigdata/hadoop/zk/myid
			*环境变量
			. /etc/profile
node04:
			mkdir /var/bigdata/hadoop/zk
			echo 3 >  /var/bigdata/hadoop/zk/myid
			*环境变量
			. /etc/profile
```
### 集群初始化启动
先启动JN (node1~node3)
```
hadoop-daemon.sh start journalnode
```
选择一个NN格式化(只在初始化时做一次)
```
hdfs namenode -format
```
在另一台机器里同步元数据(先启动node1的namenode)
```
hdfs namenode -bootstrapStandby
```
格式化zk(也是只做一次)
```
hdfs zkfc  -formatZK
```
启动集群
```
start-dfs.sh
start-yarn.sh
node03-04:
  yarn-daemon.sh start recourcemanager
```
