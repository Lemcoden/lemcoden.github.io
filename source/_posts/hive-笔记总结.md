---
title: hive-笔记总结
date: 2020-08-27 20:50:49
tags:
    - 数据仓库
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hive.jpg
---
### who,what,why
#### hive的作用
按照做笔记的习惯来说,说一个新的大数据平台框架,一般先从模型说起,而hive本身是企业级数据仓库工具,基于mapreduce计算引擎的封装(2.x之后逐渐将官方计算引擎指定为spark)所以,就其本身而言并没有模型可以讨论.
但是我们可以聊聊他的作用,他是解决什么需求的:

<!--more-->

1. 对文件以及数据的元数据进行管理,提供统一的元数据管理方式
2. 童工更加简单的方式访问大规模的数据集,使用SQL语言进行数据分析
#### 数据仓库简略介绍
说到hive就不得不提数据仓库(Data Warehouse)可简写为DW或者DWH,是为企业所有级别的决策制定过程,提供所有类型数据支持的战略集合.它是单个数据存储,处于分析性报告和决策支持目的而创建.为需要业务智能的企业,停工知道业务流程改进,监视时间,成本,质量以及控制.<br/>
一般数据仓库是将企业业务数据库,访问产生的log,以及埋点信息进行收集,并经过多次的ETL,将数据分层冗余存储,主流分层主要有四层,ODS→DW→DWD→DWT→DM层,四层数据是递进的关系,每下一层数据由上一层转换得到,数据仓库仅仅是数据集合,要真正实现其作用,要看在其之上开发的业务系统,比如数据报表系统,用户画像系统,推荐系统,人工智能等这些方面的应用.<br/>
一般基于数据仓库进行相关的数据分析大部分属于OLAP(联机事务分析)<br/>
基于星形模型与雪花模型的OLAP一般涉及两个基本概念:
* 度量:数据度量的指标,数据的世纪含义
* 维度:描述与业务主题相关的一组属性
* 事实:不同维度在某一取值下的度量

OLAP的特点
* 快速性:用户对OLAP的快速反应能力有很高的要求.系统应能在5秒内对用户的大部分分析要求作出反映
* 可分析性:OLAP系统应能处理可与应用有关的任何逻辑分析和统计分析.
* 多维性: 多维性是OLAP的关键属性.系统必须提供对数据的多维视图和分析,包括对层次维和多重层次维的完全支持
* 信息性:不论数据量有多大,也不管数据存储在何处,OLAP系统应能即使获得信息,并且管理大容量信息.

分类:
按存储方式分类:
* ROLAP:关系型在线分析处理
* MOLAP:多维在线分析处理
* HOLAP:混合型在线分析处理

按照处理方式分类:
* Server OLAP和Client OLAP

操作:<br/>
下钻,上卷,切片,切块,旋转
数据库与数据仓库的区别:
1. 数据库是对业务系统的支承,性能要求高,相应的时间短,而数据仓库对响应时间没有太多的要求,当然也是越快越好
2. 数据库存储的是某一产品线或者名业务线的数据,数据仓库可以将多个数据源经过统一的规则清洗之后进行集中统一管理
3. 数据库中存储的数据可以修改,无法保存各个历史时刻的数据,数据仓库可以保存各个时间点的数据,形成时间拉链表,可以对各个历史时刻的数据做分析
4. 数据库一次操作的数据量小,数据仓库操作的数据量大
5. 数据库使用的是实体-关系(E-R)模型,数据仓库使用的是星星模型或雪花模型
6. 数据库是面向事务级别的操作,数据仓库是面向分析的操作.


### hive的架构
架构我们一般将hive中的角色分类,hive主要四角色:<br/>
**1. 用户访问接口(client端)**
* CLI:用户可以使用hive自带的命令行接口执行HiveSQ 设置参数等
* JDBC/ODBC:用户使用JDBC或者ODBC的方式在代码中操作Hive
* 浏览器接口,用户可以在浏览器中对Hive进行操作(2.2之后淘汰)

**2. Thrift Server**
* Thrift服务,运行客户端使用Java,C++,Ruby等多种语言,通过编程的方式远程访问Hive

**3. Driver**
* Hive Driver是Hive的核心,其中包含解释器,编译器,优化器等各个组件,完成从SQL语句到MapReduce任务的解析优化执行过程

**4.metastore**
* Hive的元数据存储服务,一般将数据存储到关系型数据库,为了实现Hive元数据的持久化操作,Hive的安装包中自带了Derby内存数据库,但是实际的生产环境中一般使用mysql来存储元数据.

### hive远程数据库,metastore以及hiveserer2的配置方法
PS:hive本地模式配置略过,企业中基本不会使用到
#### hive远程数据库模式
(前提mysql服务已启动)
1. 解压安装
2. 修改环境变量
```
vi /etc/profile
export HIVE_HOME=/opt/bigdata/hive-2.3.4
将bin目录添加到PATH路径中
```
3. 修改配置文件
```
//修改文件名称，必须修改，文件名称必须是hive-site.xml
		mv hive-default.xml.template hive-site.xml
	//增加配置：
			进入到文件之后，将文件原有的配置删除，但是保留最后一行，
			从<configuration></configuration>，将光标移动到<configuration>这一行，
			在vi的末行模式中输入以下命令
			:.,$-1d
	//增加如下配置信息：
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
```
4. 拷贝JDBC驱动包
5. 执行元数据初始化
```
 schematool -dbType mysql -initSchema
```
6. 执行hive命令启动服务

#### hive metastore服务模式
假设四台服务器,node03作为服务端和node04作为客户端
1. 向node03以及node04分发hive包
2. 修改node03 hive-site.xml配置
```
<property>
  <name>hive.metastore.warehouse.dir</name>
  <value>/user/hive_remote/warehouse</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:mysql://node01:3306/hive_remote?createDatabaseIfNotExist=true</value>
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
```
4. node04 hive-site.xml配置
```
<property>
  <name>hive.metastore.warehouse.dir</name>
  <value>/user/hive_remote/warehouse</value>
</property>
<property>
  <name>hive.metastore.uris</name>
  <value>thrift://node03:9083</value>
</property>
```

5. 在node03服务端执行元数据初始化操作,schematool -dbType mysql -initSchema
6. 在node03上执行hive --service metastore,启动hive的元数据服务,是阻塞式窗口
7. 在node04上执行mysql,进入到hive的cli窗口
#### hiveServer2 配置
(在配置metastore服务的基础上)
1. 在hdfs的core-site.xml中设置超级用户的管理权限,修改配置如下:
```
在hdfs集群的core-site.xml文件中添加如下配置文件
	<property>
		<name>hadoop.proxyuser.root.groups</name>
		<value>*</value>
    </property>
    <property>
		<name>hadoop.proxyuser.root.hosts</name>
		<value>*</value>
    </property>
配置完成之后重新启动集群，或者在namenode的节点上执行如下命令
hdfs dfsadmin -fs hdfs://node01:8020 -refreshSuperUserGroupsConfiguration
hdfs dfsadmin -fs hdfs://node02:8020 -refreshSuperUserGroupsConfiguration
```

注意,这其中的root需要改成,执行hiveserver2的linux系统用户名
在node03上执行hive --service metastore元数据服务
在node04上运行hiveserer2或者hive --service hiveserver2 <br/>
**hiveserver2通过beeline进行相应的访问**<br/>
beeline通过两种方式访问:
1. 通过命令行访问 beeline -u jdbc:hive2://:/ -n name
2. 通过beeline进入client模式后输入beeline>!connect jdbc:hive2://:/ root 123
**jdbc访问方式**<br/>
将hive的lib目录里面的jar包copy到开发环境的classpath文件夹,最精简的包如下:
```
commons-lang-2.6.jar
commons-logging-1.2.jar
curator-client-2.7.1.jar
curator-framework-2.7.1.jar
guava-14.0.1.jar
hive-exec-2.3.4.jar
hive-jdbc-2.3.4.jar
hive-jdbc-handler-2.3.4.jar
hive-metastore-2.3.4.jar
hive-service-2.3.4.jar
hive-service-rpc-2.3.4.jar
httpclient-4.4.jar
httpcore-4.4.jar
libfb303-0.9.3.jar
libthrift-0.9.3.jar
log4j-1.2-api-2.6.2.jar
log4j-api-2.6.2.jar
log4j-core-2.6.2.jar
log4j-jul-2.5.jar
log4j-slf4j-impl-2.6.2.jar
log4j-web-2.6.2.jar
zookeeper-3.4.6.jar
```
下面是一个HiveJDBC连接的demo
```
package com.mashibing;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class HiveJdbcClient {

	private static String driverName = "org.apache.hive.jdbc.HiveDriver";

	public static void main(String[] args) throws SQLException {
		try {
			Class.forName(driverName);
		} catch (ClassNotFoundException e) {
			e.printStackTrace();
		}
		Connection conn = DriverManager.getConnection("jdbc:hive2://node04:10000/default", "root", "");
		Statement stmt = conn.createStatement();
		String sql = "select * from psn limit 5";
		ResultSet res = stmt.executeQuery(sql);
		while (res.next()) {
			System.out.println(res.getString(1) + "-" + res.getString("name"));
		}
	}
}

```
### hive的SQL,函数,参数
#### SQL语句之DDL语句
hive的SQL和其他的SQL语句很相似具体的数据库表操作语句语句如下:
```
create database 数据库名;  \\创建数据库
drop database 数据库名; \\删除数据库
drop table 表名; \\删除表
show databses; \\显示数据库列表
show tables; \\显示表列表
use 数据库名; \\切换数据库
desc 表名; \\显示表名
desc format 表名; \\显示表明并列出详细的format信息
创建表名,可选项比较多这里给出官方语法:
		CREATE [TEMPORARY] [EXTERNAL] TABLE [IF NOT EXISTS] [db_name.]table_name    -- 			(Note: TEMPORARY available in Hive 0.14.0 and later)
  		[(col_name data_type [COMMENT col_comment], ... [constraint_specification])]
  		[COMMENT table_comment]
  		[PARTITIONED BY (col_name data_type [COMMENT col_comment], ...)]
  		[CLUSTERED BY (col_name, col_name, ...) [SORTED BY (col_name [ASC|DESC], ...)] 				INTO num_buckets BUCKETS]
  		[SKEWED BY (col_name, col_name, ...)                  -- (Note: Available in Hive 			0.10.0 and later)]
     	ON ((col_value, col_value, ...), (col_value, col_value, ...), ...)
     	[STORED AS DIRECTORIES]
  		[
   			[ROW FORMAT row_format]
   			[STORED AS file_format]
     		| STORED BY 'storage.handler.class.name' [WITH SERDEPROPERTIES (...)]  -- 				(Note: Available in Hive 0.6.0 and later)
  		]
  		[LOCATION hdfs_path]
  		[TBLPROPERTIES (property_name=property_value, ...)]   -- (Note: Available in Hive 			0.6.0 and later)
  		[AS select_statement];   -- (Note: Available in Hive 0.5.0 and later; not 					supported for external tables)

		CREATE [TEMPORARY] [EXTERNAL] TABLE [IF NOT EXISTS] [db_name.]table_name
  			LIKE existing_table_or_view_name
  		[LOCATION hdfs_path];
 		复杂数据类型
		data_type
  		 : primitive_type
  		 | array_type
  		 | map_type
  		 | struct_type
  		 | union_type  -- (Note: Available in Hive 0.7.0 and later)
 		基本数据类型
		primitive_type
 		 : TINYINT
 		 | SMALLINT
 		 | INT
 		 | BIGINT
 		 | BOOLEAN
 		 | FLOAT
 		 | DOUBLE
  		 | DOUBLE PRECISION -- (Note: Available in Hive 2.2.0 and later)
 		 | STRING
 		 | BINARY      -- (Note: Available in Hive 0.8.0 and later)
 		 | TIMESTAMP   -- (Note: Available in Hive 0.8.0 and later)
 		 | DECIMAL     -- (Note: Available in Hive 0.11.0 and later)
 		 | DECIMAL(precision, scale)  -- (Note: Available in Hive 0.13.0 and later)
 		 | DATE        -- (Note: Available in Hive 0.12.0 and later)
 		 | VARCHAR     -- (Note: Available in Hive 0.12.0 and later)
 		 | CHAR        -- (Note: Available in Hive 0.13.0 and later)

		array_type
 		 : ARRAY < data_type >

		map_type
 		 : MAP < primitive_type, data_type >

		struct_type
 		 : STRUCT < col_name : data_type [COMMENT col_comment], ...>

		union_type
  		 : UNIONTYPE < data_type, data_type, ... >  -- (Note: Available in Hive 0.7.0 and 			later)
 		行格式规范
		row_format
 		 : DELIMITED [FIELDS TERMINATED BY char [ESCAPED BY char]] [COLLECTION ITEMS 				TERMINATED BY char]
 	       [MAP KEYS TERMINATED BY char] [LINES TERMINATED BY char]
	       [NULL DEFINED AS char]   -- (Note: Available in Hive 0.13 and later)
  			| SERDE serde_name [WITH SERDEPROPERTIES (property_name=property_value, 				property_name=property_value, ...)]
 		文件基本类型
		file_format:
 		 : SEQUENCEFILE
 		 | TEXTFILE    -- (Default, depending on hive.default.fileformat configuration)
 		 | RCFILE      -- (Note: Available in Hive 0.6.0 and later)
 		 | ORC         -- (Note: Available in Hive 0.11.0 and later)
 		 | PARQUET     -- (Note: Available in Hive 0.13.0 and later)
 		 | AVRO        -- (Note: Available in Hive 0.14.0 and later)
 		 | JSONFILE    -- (Note: Available in Hive 4.0.0 and later)
 		 | INPUTFORMAT input_format_classname OUTPUTFORMAT output_format_classname
 		表约束
		constraint_specification:
 		 : [, PRIMARY KEY (col_name, ...) DISABLE NOVALIDATE ]
 		   [, CONSTRAINT constraint_name FOREIGN KEY (col_name, ...) REFERENCES 					table_name(col_name, ...) DISABLE NOVALIDATE
*/
hivef分表语法:
alter table 表名 add partition(col_name=col_value)
alter table 表名 drop partition(col_name=col_vaule)
注意如果是多分表,添加表要添加所有嵌套的分区值
```
#### hive SQL语句之DML语句
插入数据有三种种方式:<br/>
load file方式
```
--加载本地数据到hive表
	load data local inpath '/root/data/data' into table psn;--(/root/data/data指的是本地		linux目录)
--加载hdfs数据文件到hive表
	load data inpath '/data/data' into table psn;--(/data/data指的是hdfs的目录)
```
insert data方式
```
--从表中查询数据插入结果表
	INSERT OVERWRITE TABLE psn9 SELECT id,name FROM psn
--从表中获取部分列插入到新表中
	from psn
	insert overwrite table psn9
	select id,name
	insert into table psn10
	select id
```
insert sql方式
```
--插入数据
	insert into psn values(1,'zhangsan')
```
数据更新和删除平常很少用到,如果使用请参考下面配置开启事务:
```
//在hive的hive-site.xml中添加如下配置：
	<property>
		<name>hive.support.concurrency</name>
		<value>true</value>
	</property>
	<property>
		<name>hive.enforce.bucketing</name>
		<value>true</value>
	</property>
	<property>
		<name>hive.exec.dynamic.partition.mode</name>
		<value>nonstrict</value>
	</property>
	<property>
		<name>hive.txn.manager</name>
		<value>org.apache.hadoop.hive.ql.lockmgr.DbTxnManager</value>
	</property>
	<property>
		<name>hive.compactor.initiator.on</name>
		<value>true</value>
	</property>
	<property>
		<name>hive.compactor.worker.threads</name>
		<value>1</value>
	</property>
//操作语句
	create table test_trancaction (user_id Int,name String) clustered by (user_id) into 3 			buckets stored as orc TBLPROPERTIES ('transactional'='true');
	create table test_insert_test(id int,name string) row format delimited fields 				  TERMINATED BY ',';
	insert into test_trancaction select * from test_insert_test;
	update test_trancaction set name='jerrick_up' where id=1;
//数据文件
	1,jerrick
	2,tom
	3,jerry
	4,lily
	5,hanmei
	6,limlei
	7,lucky
```
#### hive serde
如果我们数据文件是log形式像下面这样
192.168.57.4 - - [29/Feb/2019:18:14:35 +0800] "GET /bg-upper.png HTTP/1.1" 304 -
这种嵌套比较负载的方式建议使用hive serde
语法如下
```
row_format
		: DELIMITED
          [FIELDS TERMINATED BY char [ESCAPED BY char]]
          [COLLECTION ITEMS TERMINATED BY char]
          [MAP KEYS TERMINATED BY char]
          [LINES TERMINATED BY char]
		: SERDE serde_name [WITH SERDEPROPERTIES (property_name=property_value, 										            property_name=property_value, ...)]
```
示例如下
```
192.168.57.4 - - [29/Feb/2019:18:14:35 +0800] "GET /bg-upper.png HTTP/1.1" 304 -
--创建表
	CREATE TABLE logtbl (
	    host STRING,
	    identity STRING,
	    t_user STRING,
	    time STRING,
	    request STRING,
	    referer STRING,
	    agent STRING)
	  ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
	  WITH SERDEPROPERTIES (
	    "input.regex" = "([^ ]*) ([^ ]*) ([^ ]*) \\[(.*)\\] \"(.*)\" (-|[0-9]*) (-|[0-		9]*)"
	  )
  STORED AS TEXTFILE;
--加载数据
	load data local inpath '/root/data/log' into table logtbl;

```
#### hive 动态分区与分桶
要开启动态分区需要先进行如下设置
```
--hive设置hive动态分区开启
	set hive.exec.dynamic.partition=true;
	默认：true
--hive的动态分区模式
	set hive.exec.dynamic.partition.mode=nostrict;
	默认：strict（至少有一个分区列是静态分区）
--每一个执行mr节点上，允许创建的动态分区的最大数量(100)
	set hive.exec.max.dynamic.partitions.pernode;
--所有执行mr节点上，允许创建的所有动态分区的最大数量(1000)
	set hive.exec.max.dynamic.partitions;
--所有的mr job允许创建的文件的最大数量(100000)
	set hive.exec.max.created.files;
```
hive动态分区语法
```
-Hive extension (dynamic partition inserts):
	INSERT OVERWRITE TABLE tablename PARTITION (partcol1[=val1], partcol2[=val2] ...) 		select_statement FROM from_statement;
	INSERT INTO TABLE tablename PARTITION (partcol1[=val1], partcol2[=val2] ...) 			select_statement FROM from_statement;
```
hive分桶
* hive分桶是对列值取hash值的方式,将不同的数据放到不同的文件中存储
* 对于hive中每一个表,分区都可以进一步进行分桶
* 由列的hash值除以桶的个数据决定每条数据划分到哪个桶中
hive分桶的配置
```
--设置hive支持分桶
	set hive.enforce.bucketing=true;
```
hive分桶的抽样查询
```
select * from bucket_table tablesample(bucket 1 out of 4 on columns)
-TABLESAMPLE语法：
	TABLESAMPLE(BUCKET x OUT OF y)
		x：表示从哪个bucket开始抽取数据
		y：必须为该表总bucket数的倍数或因子
```
#### hive的函数
hive函数有多种设置方法

1. 在hive-site.xml 文件中设置
2. 在本地home文件新建一个.hiverc文件,可以在里面设置参数
3. 通过hive -hiveconf  key=vaule的方式启动
4. 在hive命令行中用set方法设置

通过在hive当中设置
#### hive的运行方式
1.命令行方式或者控制台模式
2.脚本运行方式
3.JDBC方式
4.WEB GUI方式
**命令行模式的一些tips**
* 直接输入SQL语句,select * from table_name
* 命令行与hdfs交互 dfs ls /
* 命令行与linux交互 !pwd 或者!ls /
**脚本运行方式**
```
--hive直接执行sql命令，可以写一个sql语句，也可以使用;分割写多个sql语句
	hive -e ""
--hive执行sql命令，将sql语句执行的结果重定向到某一个文件中
	hive -e "">aaa
--hive静默输出模式，输出的结果中不包含ok，time token等关键字
	hive -S -e "">aaa
--hive可以直接读取文件中的sql命令，进行执行
	hive -f file
--hive可以从文件中读取命令，并且执行初始化操作
	hive -i /home/my/hive-init.sql
--在hive的命令行中也可以执行外部文件中的命令
	hive> source file (在hive cli中运行)
```
#### hive视图
hive视图仅仅是数据的一种逻辑表示,本质上就是一条SQL语句的结果集,(hive3.0引入的物化视图除外)
当我们需要写一个非常长的SQL时可以先定义视图这样一个"中间表"
hive视图语法:
```
--创建视图：
	CREATE VIEW [IF NOT EXISTS] [db_name.]view_name
	  [(column_name [COMMENT column_comment], ...) ]
	  [COMMENT view_comment]
	  [TBLPROPERTIES (property_name = property_value, ...)]
	  AS SELECT ... ;
--查询视图：
	select colums from view;
--删除视图：
	DROP VIEW [IF EXISTS] [db_name.]view_name;
```
**hive 索引**
索引在hive当中很少用到,因为hive中索引配置比较麻烦,每次更新数据时还需要更新一下索引,但是如果公司有需求时,请参考如下SQL:
```--创建索引：
	create index t1_index on table psn2(name)
	as 'org.apache.hadoop.hive.ql.index.compact.CompactIndexHandler' with deferred 			rebuild in table t1_index_table;
--as：指定索引器；
--in table：指定索引表，若不指定默认生成在default__psn2_t1_index__表中
	create index t1_index on table psn2(name)
	as 'org.apache.hadoop.hive.ql.index.compact.CompactIndexHandler' with deferred 			rebuild;
--查询索引
	show index on psn2;
--重建索引（建立索引之后必须重建索引才能生效）
	ALTER INDEX t1_index ON psn2 REBUILD;
--删除索引
	DROP INDEX IF EXISTS t1_index ON psn2;
```
