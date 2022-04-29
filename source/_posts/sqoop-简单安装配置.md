---
title: sqoop 简单安装配置
date: 2020-11-10 09:52:14
tags:
	- sqoop
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/sqoop.jpg
---

```
$HIVE_SRC/build/dist/bin/hive 
--auxpath $HIVE_SRC/build/dist/lib/hive-hbase-handler-0.9.0.jar,
$HIVE_SRC/build/dist/lib/hbase-0.92.0.jar,
$HIVE_SRC/build/dist/lib/zookeeper-3.3.4.jar,
$HIVE_SRC/build/dist/lib/guava-r09.jar
--hiveconf 
hbase.zookeeper.quorum=zk1.yoyodyne.com,zk2.yoyodyne.com,zk3.yoyodyne.com
```

<!--more-->

```
CREATE TABLE hbase_table_1(key int, value string) 
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,cf1:val")
TBLPROPERTIES ("hbase.table.name" = "xyz", "hbase.mapred.output.outputtable" = "xyz");
```

