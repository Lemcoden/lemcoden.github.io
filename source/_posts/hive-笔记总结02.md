---
title: hive-笔记总结02
date: 2020-09-04 15:44:41
tags:
    - 数据仓库
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hive.jpg
---
我们接着上次的hive继续总结
### 配置补充,hiveserer2的高可用
node2-hive-site.xml

<!--more-->

```
<property>  
  <name>hive.metastore.warehouse.dir</name>  
  <value>/user/hive/warehouse</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionURL</name>  
  <value>jdbc:mysql://node01:3306/hive?createDatabaseIfNotExist=true</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionDriverName</name>  
  <value>com.mysql.jdbc.Driver</value>  
</property>     
<property>  
  <name>javax.jdo.option.ConnectionUserName</name>  
  <value>root</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionPassword</name>  
  <value>123</value>  
</property>
<property>
  <name>hive.server2.support.dynamic.service.discovery</name>
  <value>true</value>
</property>
<property>
  <name>hive.server2.zookeeper.namespace</name>
  <value>hiveserver2_zk</value>
</property>
<property>
  <name>hive.zookeeper.quorum</name>
  <value>node01:2181,node02:2181,node03:2181</value>
</property>
<property>
  <name>hive.zookeeper.client.port</name>
  <value>2181</value>
</property>
<property>
  <name>hive.server2.thrift.bind.host</name>
  <value>node02</value>
</property>
<property>
  <name>hive.server2.thrift.port</name>
  <value>10001</value>
</property>

```
node4-hive-site.xml
```
<property>  
  <name>hive.metastore.warehouse.dir</name>  
  <value>/user/hive/warehouse</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionURL</name>  
  <value>jdbc:mysql://node01:3306/hive?createDatabaseIfNotExist=true</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionDriverName</name>  
  <value>com.mysql.jdbc.Driver</value>  
</property>     
<property>  
  <name>javax.jdo.option.ConnectionUserName</name>  
  <value>root</value>  
</property>  
<property>  
  <name>javax.jdo.option.ConnectionPassword</name>  
  <value>123</value>  
</property>
<property>
  <name>hive.server2.support.dynamic.service.discovery</name>
  <value>true</value>
</property>
<property>
  <name>hive.server2.zookeeper.namespace</name>
  <value>hiveserver2_zk</value>
</property>
<property>
  <name>hive.zookeeper.quorum</name>
  <value>node01:2181,node02:2181,node03:2181</value>
</property>
<property>
  <name>hive.zookeeper.client.port</name>
  <value>2181</value>
</property>
<property>
  <name>hive.server2.thrift.bind.host</name>
  <value>node04</value>
</property>
<property>
  <name>hive.server2.thrift.port</name>
  <value>10001</value>
</property>

```
**beeline连接**<br/>
!connect jdbc:hive2://node01,node02,node03/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2_zk root 123
#### hive权限管理
在hiveserver2的节点添加如下配置:
```
<property>
  <name>hive.server2.enable.doAs</name>
  <value>false</value>
</property>
<property>
  <name>hive.users.in.admin.role</name>
  <value>root</value>
</property>
<property>
  <name>hive.security.authorization.manager</name>  <value>org.apache.hadoop.hive.ql.security.authorization.plugin.sqlstd.SQLStdHiveAuthorizerFactory</value>
</property>
<property>
  <name>hive.security.authenticator.manager</name>
  <value>org.apache.hadoop.hive.ql.security.SessionStateUserAuthenticator</value>
</property>
```
中间的root改为自己启动hive的用户名,这样以后通过其他角色连接你的hive,操作数据库和表就需要更加细粒度的权限<br/>
角色授权命令如下
```
--角色的添加、删除、查看、设置：
-- 创建角色
CREATE ROLE role_name;  
-- 删除角色
DROP ROLE role_name;
-- 设置角色
SET ROLE (role_name|ALL|NONE);
-- 查看当前具有的角色
SHOW CURRENT ROLES;  
-- 查看所有存在的角色
SHOW ROLES;  

grant 操作名 on psn8 to user 用户名;
为某个用户授权
revoke 操作名 on psn8 from user 用户名;
移除某个用户的权限
```
#### hive优化
1. 查看hive的执行计划
hive的SQL语句在执行之前需要将SQL转换成Mapreduce任务,因此需要了解具体的转换过程.可以在SQL语句中输入如下命令查看具体的执行计划
```
--查看执行计划，添加extended关键字可以查看更加详细的执行计划
explain [extended] query
```
2. hive的抓取策略
理论上来说hive会把所有的SQL语句转换为Mapreduce操作,但实际操作中比如说select,我们看到他并没有输出mapreduce计算任务的log,只不过Hive在转换SQL语句的过程中会做部分优化,使某些简单的操作不再需要转换成MapReduce.
1. select 仅支持本表字段
2. where 仅对本表字段做条件过滤
```
set hive.fetch.task.conversion=none/more
```
3.hive本地模式
在开发测试阶段,可以设置hive的本地模式,提高SQL语句的执行效率,验证SQL是否执行正确
```
set hive.exec.mode.local.auto=true;
```
注意:要想使用Hive的本地模式,加载数据文件大小不能超过128MB,如果超过128M,计算设置本地模式,也会按照集群模式运行
```
set hive.exec.mode.local.auto.inputbytes.max=128M
```
4. hive并行模式
在SQL语句足够复杂的情况下,可能在一个SQL语句中包含多个子查询语句,且多个自查询语句之间没有任何任何依赖关系,此时,可以设置hive的并行度
```
允许设置hive并行执行
set hive.exec.parallel=true;
```
hive的并行度并不是无限增加的,在一次SQL计算中,可以通过以下参数来设置并行的job的个数
```set hive.exec.parallel.thread.number

```

5. hive严格模式
hive为了提高SQL语句的执行效率,可以设置严格模式,充分利用Hive的某些特点<br/>
```
set hive.mapred.mode=strict;
```

* 对于分区表,必须添加where对于分区字段的条件过滤
* order by语句必须包含limit输出限制
* 限制执行笛卡尔积的查询


6. Hive排序
在编写SQL语句的过程中,很多情况下徐亚对数据进行排序操作,Hive中支持多种排序操作适合不同的应用场景
* Order By-对于查询结果做全排序,只允许有一个reduce处理
* Sort By 对于单个reduce的数据进行排序
* Distribute By-分区排序,经常和Sort By结合使用
* Cluster by 相当于Sort By + Distribute By 无法倒序排列

7. Hive join
* Hive在多个表的join操作时尽可能多的使用相同的连接键,这样转换MR任务会转换成少的MR任务
* 手动Map join在map端完成join操作
```
--SQL方式,在SQL语句中添加Mapjoin标记
SELECT MAPJOIN(smallTable) smallTable.Key,bigTable.value
FROM smallTable JOIN bigTable ON smallTable.key = bigTabel.key
```
* 开启自动的Map join
```
--通过修改一下配置启用自动的mapjoin;
set hive.auto.convert.join = true;
--（该参数为true时，Hive自动对左边的表统计量，如果是小表就加入内存，即对小表使用Map join）
--相关配置参数：
hive.mapjoin.smalltable.filesize;
```
* **大表join大表**
* 空key过滤:有时join超时是因为某些key对应的数据太多,而相同对应的数据就会发送到相同的reducer,从而导致内存不够,此时我们应该仔细分析这些异常的key,很多情况下,这些key对应的数据是异常数据,我们需要在SQL语句进行
* 空key转换:有时虽然某个key为空对应的数据很多,但是相应的不是异常数据,必须要包含在join的结果中,此时我们可以表a中key为空的字段赋值一个随机的值,使得数据随机均匀地分布到不同的reducer上
9. 合并小文件
hive在操作的时候,如果文件数目小,容易在文件存储造成压力,给hdfs造成压力,影响效率

```
--设置合并属性
--是否合并map输出文件：
set hive.merge.mapfiles=true
--是否合并reduce输出文件：
set hive.merge.mapredfiles=true;
--合并文件的大小：
set hive.merge.size.per.task=256*1000*1000
```

10. 合理设置Map以及Reduce的数量

```
--Map数量相关的参数
--一个split的最大值，即每个map处理文件的最大值
set mapred.max.split.size
--一个节点上split的最小值
set mapred.min.split.size.per.node
--一个机架上split的最小值
set mapred.min.split.size.per.rack
--Reduce数量相关的参数
--强制指定reduce任务的数量
set mapred.reduce.tasks
--每个reduce任务处理的数据量
set hive.exec.reducers.bytes.per.reducer
--每个任务最大的reduce数
set hive.exec.reducers.max
```

11. JVM重用

```
/*
适用场景：
	1、小文件个数过多
	2、task个数过多
缺点：
	设置开启之后，task插槽会一直占用资源，不论是否有task运行，直到所有的task即整个job全部执行完成时，才会释放所有的task插槽资源！
*/
set mapred.job.reuse.jvm.num.tasks=n;--（n为task插槽个数）
```
