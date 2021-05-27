---
title: sql语句笔记01
date: 2020-11-12 22:15:03
categories: mysql
tags:
    - sql语句
    - sql练习
cover_picture: http://picture.lemcoden.xyz/cover_picture/sql.jpeg
---

#### mysql四大排名函数

row_number: 连续 不重复 

rank: 不连续 重复

dense_rank: 连续 重复

ntile:有参数 入参group_num, 将数据分成group_num个组排序编号

<!--more-->

#### 异常bug You can't specify target table for update in FROM clause

You can't specify target table for update in FROM clause含义:不能在同一表中查询的数据作为同一表的更新数据。

所有我们要在Select子句上在嵌套一层临时表

如：

```sql
Delete from 表名 where 参数 in (select a.* from (真实的Select子句) a)
```

#### 字符判空

isnull()

```
select * from users where email = 'xxxx' and isnull(deletedAt)
```

is null

```
select * from users where email = 'xxxx' and deletedAt is null
```

is not null

```
select * from users where email = 'xxxx' and deletedAt is not null
```

!isnull()

```
select * from users where email = 'xxxx' and !isnull(deletedAt)
```

```
select * from users where email = 'xxxx' and not isnull(deletedAt)
```

isfull

当查询条件为 null，用指定字符替代

```
select name, isfull(gender,'未知') as gender from users where email = 'xxxx'
```

#### mysql日期函数查询blog

https://www.cnblogs.com/dreamboycx/p/11099425.html

#### 关于类型转换与精度

CASE(value AS type)

ROUND(value,精度)

CONVERT（value，type）

> type:

> * 二进制，同带binary前缀的效果 : BINARY   

> * 字符型，可带参数 : CHAR()   

> * 日期 : DATE   

> * 时间: TIME   

> * 日期时间型 : DATETIME   

> * 浮点数 : DECIMAL    

> * 整数:SIGNED   

> * 无符号整数 : UNSIGNED 

FORMAT（X,D）：强制保留D位小数，整数部分超过三位的时候以逗号分割，并且返回的结果是string类型的

Having关键字 为了解决where后面不能跟小数的问题

#### CASE WHEN 用法样例

```
CASE WHEN SCORE = 'A' THEN '优'
     WHEN SCORE = 'B' THEN '良'
     WHEN SCORE = 'C' THEN '中' ELSE '不及格' END
```

#### If 函数的用法

```
SELECT IF(sva=1,"男","女") AS s FROM table_name 
```

