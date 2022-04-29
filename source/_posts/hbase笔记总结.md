---
title: hbase笔记总结
date: 2020-09-15 15:43:36
categories: hadoop生态
tags:
    - hadoop生态
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hbase.jpg
---
### 1.先从关系型数据库与非关系型数据讲起
**关系型数据库** 就是我们传统的像mysql,oracle,sql server这样的具有自己的二维固定的数据结构<br/>
优点:
* 易于维护:都是使用表结构,格式一致

* 使用方便: SQL语言通用,可用于复杂查询

* 复杂操作:支持SQL,可用于一个表以及多个表之间非常复杂的查询

  <!--more-->

缺点:
* 读写性能差,尤其是海量数据的高效率读写
* 固定的表结构,灵活度稍欠
* 高并发读写需求,传统关系型数据库,硬盘IO是一个很大的瓶颈

**非关系型数据库**
非关系型数据库严格意义上不是一种数据库,应该是一种数据结构化存储方法的集合,可以是文档或者键值对<br/>
优点:
* 格式灵活:存储数据的格式可以是key,value,文档形式,图片形式等等,使用灵活,应用场景广泛,而关系型数据库则只支持基础类型
* 速度快:nosql 可以使用硬盘或随机存储器作为载体,而关系型数据库只能使用硬盘
* 高扩展性
* 成本低:nosql数据库部署简单,基本都是开源软件

缺点:
* 不提供sql支持,学习和使用成本高
* 无事务处理
* 数据结构相对复杂,复杂查询方面稍欠
### 2.HBase数据模型
* **rowkey**
1. 决定一行数据,每行记录的唯一标识
2. 按照字典序排序
3. rowkey只能存储64K的字节数据

* **Column Family & Qualifier**
1. Hbase表中的每个列都归属于某个列族,列族作为表模式(schema)定义的一部分预先给出
2. 列名以列族作为前缀,每个列族都可以有多个列成员(column);如course:math,course:english,新的列祖成员可以随后按需动态加入;
3. 权限控制,存储以及调优都是再列族层面进行的
4. HBase把同一列族里面的数据存储再同一目录下,由几个文件保存

* **TimeStamp时间戳**
1. 在HBase每个cell存储单元对同一份数据有多个版本,根据唯一的时间戳来区分每个版本之间的差异,不同版本的数据按照时间倒序排序,最新的数据版本排在最前面
2. 时间戳的类型是64位整型
3. 时间戳可以由HBase(在数据写入时自动)赋值,此时时间戳是精确到毫秒的当前系统时间.
4. 时间戳也可以由客户显式赋值,如果应用程序要避免数据版本冲突,就必须自己生成具有唯一性的时间戳.
* **Cell**
1. 由行和列的坐标交叉决定
2. 单元格是有版本的
3. 单元格的内容是未解析的字节数组
1.由(rowkey,column(=+),version)唯一确定的单元
2.cell中的数据没有类型的,全部是由字节数组形式存贮
### 3.HBase架构
角色介绍:
* **Client**
1. 包含访问HBase的接口并维护cache来加快对HBase的访问
* **Zookeeper**
1. 保证任何时候,集群中只有一个活跃的master
2. 存储所有region的寻址入口
3. 实施监控region server的上线和下限信息,并通知master
4. 存储Hbase的schema和table元数据
* **Master**
1. 为region server 分配region
2. 负责region server的负载均衡
3. 发现失效的region server并重新分配其上的region
4. 管理用户对table的增删改操作
* **RegionServer**
1. region server维护region,处理对这些region的IO请求
2. region server负责切分运行过程中变得过大的region
**regionserver组件介绍**
* **region**
1. Hbase自动把表水平划分成多个区域(region),每个region会保存表里某段连续的数据
2. 每个表一开始只有一个region,随着数据不断插入,region不断增大,当增大到一个阈值的时候,region会等分成两个新的region
3. 当table中的行不断增多,就会由越来越多的region.这样一张完整的表被保存到多个regionserver上
* Memstore与storefile
1. 一个region由多个store组成,一个store对应一个CF(列族)
2. store包括位于内存中的memstore和位于磁盘的storefile,
3. 当storefile文件的数量增长到一定阈值,系统会进行合并(minor,major),在合并过程中会进行版本合并和删除工作(major),形成更大的storefile
4. 当一个region所有的storefile的大小和数量超过一定阈值后,会把当前的region分割为两个,并由hmaster分配到相应的regionserver服务器,实现负载均衡
5. 客户端检索数据,先在memstore找,找不到取blockcache,找不到再找storefile
**注意问题**
1. HRegion是HBase中分布式存储和负载均衡的最小单元,最小单元就表示不同的HRegion可以分布在不同的HRegion server的上
2. HRegion由一个或者多个Store组成,每个store保存一个columns family
3. 每个store又由一个memStore和0至多个StoreFile组成.如图:StoreFile以HFile保存在HDFS上
**HBase读写流程**
* **读流程**
1. 客户端从zookeeper中获取meta表的regionserver节点信息
2. 客户端访问meta表所在的regionserver节点,获取到region所在的regionserver的节点信息
3. 客户端访问具体的region所在的regionserver,找到对应的region及store
4. 首先从memstore中读取数据,如果读取到了那么直接将数据返回,如果没有,则去blockcache读取数据
5. 如果blockcache中读取到数据,则直接返回数据给客户端,如果读取不到,则遍历storefile文件,查找数据
6. 如果storefile中读取不到数据,则客户端为空,如果读取到数据,那么需要将数据先缓存到blockcache中(方便下一次读取),然后再将数据返回给客户端
7. blockcache是内存空间,如果缓存的数据比较多,满了之后会采用LRU策略,将比较老的数据进行删除

* **写流程**
1. 客户端从zookeeper中获取meta表所在的regionserver节点信息
2. 客户端访问meta表所在的regionserver节点,获取到region所在的regionserver信息
3. 客户端访问具体的region所在的regionserver,找到对应的reion以及store
4. 开始写数据,数据的时候会先向hlog中写一份数据(方便memstore中数据丢失后能沟根据hlog恢复数据,向hlog中写数据的时候也是优先写入内存,后台会有一个线程定期异步刷写数据到hdfs,如果hlog的数据也写入失败,那么数据就会发生丢失)
5. hlog写数据完成之后,会将数据写入到memstore,memstore默认大小是64M,当memstore满了之后会进行统一的溢写操作,将memstore中的数据持久化到hdfs中.
6. 频繁的溢写会导致产生很多的小文件,因此会进行文件的合并,文件合并的时候会有两种方式,minor和major,minor表示小范围文件的合并,major表示将所有的storefile文件都合并成一个,具体详细过程,后续会讲解

### HBASE 分布式搭建

#### 1.搭建方式说明

```
By default,HBase run in standalone mode,Both standalone mode and pseudo-ditributed mode are provided for the purpose of small-scale testing.For a production environment, distributed mode is advised,multiple instances of Hbase daemons run on multiple servers in the cluster
```

#### 2.搭建步骤

1. 将集群所有的节点的hosts的文件配置完成

2. 将集群中所有节点的防火墙关闭

3. 将集中的所有检点的事件设置一致

   ```shell
   yum install ntpdate
   ntpdate ntp1.aliyun.com4.
   ```

4. 将所有的节点设置免密登陆

   ```shell
   ssh-keygen
   ssh-copy-id -i /root/.ssh/id_rsa.pub node01(节点名称)
   ```

5. 解压hbase安装包

   ```shell
   tar xzvf hbase-2.0.5-bin.tar.gz -C /opt/bigdata
   cd hbase-2.0.5/
   ```

6. 在/etc/profile文件中配置HBase的环境变量

   ```
   export HBASE_HOME=/opt/bigdata/hbase-2.0.5
   将$HBASE_HOME设置到PATH路径中
   ```

7. 进入到/opt/bigdata/hbase-2.0.5/conf 目录中,在hbase-env.sh文件中添加JAVA_HOME

   ```
   设置JAVA的环境变量
   JAVA_HOME=/usr/java/jdk1.8.0_181-amd64
   设置是否使用自己的zookeeper实例
   HBASE_MANAGES_ZK=false
   ```

   

8. 进入到/opt/bigdata/hbase-2.0.5/conf目录中,在hbase-site.xml文件中添加hbase相关属性

   ```
   <configuration>
     <property>
       <name>hbase.rootdir</name>
       <value>hdfs://mycluster/hbase</value>
     </property>
     <property>
       <name>hbase.cluster.distributed</name>
       <value>true</value>
     </property>
     <property>
       <name>hbase.zookeeper.quorum</name>
       <value>node02,node03,node04</value>
     </property>
   </configuration>
   ```

9. 修改regionserver文件,设置regionservert分布在哪台节点

   ```
   node02
   node03
   node04
   ```

   10.如果需要配置Master的高可用,需要在conf目录下创建backup-masters 文件.并添加如下内容

   ```shell
   node04
   ```

   11.拷贝hdfs-site.xml文件到conf目录下

   ```
   cp /opt/bigdate/hbase-2.6.5/etc/hadoop/hdfs-site.xml /opt/bigdata/hbase-2.0.5/conf
   ```

   12.在任意目录下运行hbase shell的命令,进入hbase的命令进行相关的操作

