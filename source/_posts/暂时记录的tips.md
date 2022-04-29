---
title: 暂时记录的tips
date: 2020-09-22 10:59:19
categories: hadoop生态
tags:
    - hadoop生态
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hdfs.jpg
mathjax: true
---
#### hadoop mr HistoryServer的配置和启动命令

mapred-site.xml

```
<property>
<name>mapreduce.jobhistory.address</name>
<value>node04:10020</value>
</property>
<property>
<name>mapreduce.jobhistory.webapp.address</name>
<value>node04:19888</value>
</property>
```

<!--more-->

yarn-site.xml

```
<property>       
<name>yarn.log-aggregation-enable</name>       
<value>true</value>   
</property>   
```



```
mr-jobhistory-daemon.sh start historyserver
```



### kafka和flume的区别

1. kafka的数据直接写入磁盘(定死的),因为使用顺序存储和zero-copy其传输效率极高,flume的channel默认内存,不过考虑到持久化可以选择文件存储或者sql存储,但效率极低.
2. kafka可以进行重复消费,应用广泛,一般应用于实时或者流式场景,flume不可重复消费,仅可作为日志收集框架使用.
3. flume HDFSsink,文件大小滚动最好设置为128MB.
4. flume 1.8.0版有Fileposition属性进行断点续传
5. nginx的默认conf目录在/usr/local/nginx/conf/
6. spark flink的区别,flink对于状态的管理非常到位,并且flink可以很简洁的解决复杂事务
7. ETL的四件事情,过滤脏数据,过滤的规则自己指定
                IP地址的映射实际地址
                字符串对应的解析工作
                设计HBase的RowKey

#### 重启网卡

```
systemctl restart network
```

#### virtualBox 重新设置虚拟盘的 uuid

```
VBoxManage internalcommands sethduuid hadoop01.vdi 
```

#### vim替换命令

```
:%s/hadoop/node/g
```

#### HBase异常解决方法

```
ERROR: org.apache.hadoop.hbase.PleaseHoldException: Master is initializing
```

先检查时间是否同步

```
yum install ntpdate
ntpdate ntp1.aliyun.com
```

如果是重装过的hbase,要删除zookeeper里的目录

```
zkCli.sh
rmr /hbase
```

#### sqoop异常解决方法

```
错误: 找不到或无法加载主类 org.apache.sqoop.Sqoop
```

解决方法: 把$SQOOP_HOME下的sqoop-1.4.6.jar 复制到$HADOOP_HOME/share/hadoop/mapreduce/lib下

```
Could not load db driver class: com.mysql.jdbc.Drive
```

解决方法: 把jdbc的jar,放到

$HADOOP_HOME/share/hadoop/mapreduce/lib下

$SQOOP_HOME/lib下

```
发生类似的警告
Please set $ACCUMULO_HOME to the root of your Accumulo installation.
```

vim $SQOOP_HOME/bin/configured-sqoop

把相关代码注释掉

#### Hive整合Hbase

在hive客户端节点的$HIVE_HOME/conf/hive-site.xml添加

```
        <property>
                <name>hbase.zookeeper.quorum</name>
                <value>hadoop02,hadoop03,hadoop04</value>
        </property>
```

hive内部表参考SQL

```
CREATE TABLE hbase_table_1(key int, value string) 
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,cf1:val")
TBLPROPERTIES ("hbase.table.name" = "xyz", "hbase.mapred.output.outputtable" = "xyz");
```

hive外部表参考SQL

```
CREATE EXTERNAL TABLE hbase_table_2(key int, value string) 
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES ("hbase.columns.mapping" = "cf1:val")
TBLPROPERTIES("hbase.table.name" = "some_existing_table", "hbase.mapred.output.outputtable" = "some_existing_table");
```

#### HDFS安全模式相关命令

hadoop dfsadmin -safemode leave  强制NameNode退出安全模式
hadoop dfsadmin -safemode enter  进入安全模式
hadoop dfsadmin -safemode get   查看安全模式状态
hadoop dfsadmin -safemode wait  等待一直到安全模式结束

#### 复杂HQL语句示例

```
from (
  select 
    pl, from_unixtime(cast(s_time/1000 as bigint),'yyyy-MM-dd') as day, u_ud, 
    (case when count(p_url) = 1 then "pv1" 
      when count(p_url) = 2 then "pv2" 
      when count(p_url) = 3 then "pv3" 
      when count(p_url) = 4 then "pv4" 
      when count(p_url) >= 5 and count(p_url) <10 then "pv5_10" 
      when count(p_url) >= 10 and count(p_url) <30 then "pv10_30" 
      when count(p_url) >=30 and count(p_url) <60 then "pv30_60"  
      else 'pv60_plus' end) as pv 
  from event_logs 
  where 
    en='e_pv' 
    and p_url is not null 
    and pl is not null 
    and s_time >= unix_timestamp('2019-08-13','yyyy-MM-dd')*1000 
    and s_time < unix_timestamp('2019-08-14','yyyy-MM-dd')*1000
  group by 
    pl, from_unixtime(cast(s_time/1000 as bigint),'yyyy-MM-dd'), u_ud
) as tmp
insert overwrite table stats_view_depth_tmp 
  select pl,day,pv,count(u_ud) as ct where u_ud is not null group by pl,day,pv;
```

#### maven将Jar包打进资源文件

```
<build>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
                <includes>
                    <include>*.txt</include>
                </includes>
                <excludes>
                    <exclude>*.xml</exclude>
                    <exclude>*.yaml</exclude>
                </excludes>
            </resource>
        </resources>
 </build>

```

```
create function platform_convert as "com.mashibing.transformer.hive.PlatformDimensionUDF" using jar "hdfs://mycluster/msb/transformer/transformer-0.0.1.jar"
```

#### 打印当前进程

```
echo $BASHPID
echo $$
```

#### 查看端口占用

```
netstat  -anp  |grep   端口号
```

#### vim 编辑状态下,sudo身份写入

```
:w !sudo tee %
```

#### Cannot resolve plugin org.apache.maven.plugins:maven-deploy-plugin:2.8.2

进入maven本地库清空相关文件夹

然后进入clean一下项目,缺少哪个插件就执行哪个maven命令就会重新下载

#### hexo支持数学公式

blog目录下

```
npm uninstall hexo-renderer-marked --save
npm install hexo-renderer-kramed --save
```

修改主题下配置文件_config.yml

```
mathjax:
  enable: true
```

为了加快渲染速度,渲染器之后在渲染标签为true的文章下进行渲染

设置渲染标签

```
title: 暂时记录的tips
date: 2020-09-22 10:59:19
categories: hadoop生态
tags:
    - hadoop生态
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hdfs.jpg
mathjax: true
```

演示
$$
\sum_{n=1}^{100}{a}
$$

#### hexo配置mathJax

很多人配置后本地显示,上传到github库后不显示,看下面这个

https://www.jianshu.com/p/5623c5e35c93