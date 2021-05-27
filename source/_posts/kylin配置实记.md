---
title: kylin配置实记
date: 2019-12-31 10:59:44
categories: hadoop生态
tags:
	- 数据仓库框架
cover_picture: http://picture.lemcoden.xyz/cover_picture/kylin_logo.jpg
---
### 介绍
Apache Kylin是Hadoop大数据平台上的一个开源OLAP引擎。它采用多维立方体预计算技术，可以将大数据的SQL查询速度提升到亚秒级别。相对于之前的分钟乃至小时级别的查询速度，亚秒级别速度是百倍到千倍的提升，该引擎为超大规模数据集上的交互式大数据分析打开了大门。
笔者作为一个大数据工程师，kylin这种查询速度极高的大数据OLAP引擎是必须需要学习掌握的，此文便是关于kylin的配置过程以及过程中遇到的一些问题，后续笔者可能会写多篇博客来阐述kylin开发遇到的问题以及如何解决。
<!-- more -->
### 下载安装
下载地址如下
http://kylin.apache.org/cn/download/
PS：kylin是我们中国人主导开发的apache顶级项目，因此google浏览器开启翻译模式，翻译的中文读起来特别流畅
根据自己的HBASE以及HADOOP的版本下载相应版本的kylin安装包
比如说我的HBase版本位1.4，所以我下载的是2.6版本的kylin，其实正式的大数据框架部署时，应该选择比当前版本低一些的框架，让框架稳定运行。
Linux wget命令下载如下
```
	wget https://www.apache.org/dyn/closer.cgi/kylin/apache-kylin-2.6.4/apache-kylin-2.6.4-bin-hbase1x.tar.gz
```
下载完成后解压缩，配置环境变量
```
	tar -zxvf apache-kylin-2.5.0-bin-hbase1x.tar.gz -C \\你的目标文件夹
	cd apache-kylin-2.5.0-bin-hbase1x
	export KYLIN_HOME=`pwd`
```

### spark计算框架的配置

现在大部分的计算框架都使用的spark，mapreduce因为需要大量的磁盘IO而被人诟病，所以笔者下面演示如何给kylin配置spark计算框架
你可以通过运行kylin的脚本下载spark，或者直接配置系统的环境变量指向已有的spark
运行脚本进行下载：
```
$KYLIN_HOME/bin/download-spark.sh
```
脚本会把spark下载到在kylin目录下的spark目录

配置环境变量
```
export SPARK_HOME=/path/to/spark
```
在conf/kylin.properties文件当中添加spark的相关配置

```
kylin.engine.spark-conf.spark.submit.deployMode=cluster
kylin.engine.spark-conf.spark.yarn.queue=default
kylin.engine.spark-conf.spark.driver.memory=2G
kylin.engine.spark-conf.spark.executor.memory=1G
kylin.engine.spark-conf.spark.yarn.executor.memoryOverhead=1024
kylin.engine.spark-conf.spark.executor.instances=2
kylin.engine.spark-conf.spark.executor.cores=1
kylin.engine.spark-conf.spark.shuffle.service.enabled=false
kylin.engine.spark-conf.spark.network.timeout=600
kylin.engine.spark-conf.spark.eventLog.enabled=true
kylin.engine.spark-conf.spark.hadoop.dfs.replication=2
kylin.engine.spark-conf.spark.hadoop.mapreduce.output.fileoutputformat.compress=true
kylin.engine.spark-conf.spark.hadoop.mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.DefaultCodec
#kylin.engine.spark-conf.spark.io.compression.codec=org.apache.spark.io.SnappyCompressionCodec
kylin.engine.spark-conf.spark.eventLog.dir=hdfs:///kylin/spark-history
kylin.engine.spark-conf.spark.history.fs.logDirectory=hdfs:///kylin/spark-history
kylin.engine.spark-conf.spark.yarn.archive=hdfs://node1:8020/kylin/spark/spark-libs.jar
```
最后一个配置项指的是spark的类库的位置，我们放到hdfs上以防丢失。


将spark目录下的lib jar包合并为spark-libs.jar并上传到hdfs
```
jar cv0f spark-libs.jar -C //spark的lib目录
hadoop fs -put spark-libs.jar /kylin/spark/
```
这样我们就完成了spark的配置

### 启动并访问

测试环境

```
$KYLIN_HOME/bin/check-env.sh
```
启动麒麟
```
$KYLIN_HOME/bin/kylin.sh start
```
添加样本数据
```
$KYLIN_HOME/bin/simple.sh start
```
通过
http://<hostname>:7070/kylin
访问麒麟
用户名密码分别为admin,kylin
### 构建cube时，hive报错的解决方案
单击Web界面的Model→Data source下的“Load Hive Table”图标准备设计cube时，出现oops!org/apache/hadoop/hive/conf/HiveConf的字样
查找日志发现java.lang.NoClassDefFoundError: org/apache/hadoop/hive/conf/HiveConf 找不到hive的类库
所以需要将hive lib目录下的类库copy 到kylin lib当中，并在bin/kylin.sh中将 hive_dependency 加入到 HBASE_CLASSPATH_PREFIX 中,重启或者reload一下配置。
