---
title: redis笔记05
tags:
  - 内存数据库
categories: redis
cover_picture: 'https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/redis.jpeg'
date: 2020-11-23 22:32:48
---


### redis常见问题

```
jedis,luttce,springboot:low/high level
```

#### 击穿

**<font color=MediumVioletRed>key过期造成并发访问数据库</font>**

```mermaid
graph LR
	id0((用户<br/>client)) --> id2
	id2[nginx] --> id3[ ]
	id3 --> id4
	id4((client<br/>server)) --1.null--> id5[redis<br/>缓存<br/>key过期时间,LRU,LFU]
	id4 --2.setInx--> id5
	id4 --3.只有获得锁的去访问DB--> id1[DBMySQL]
	id4 --> id1
	before[before<br/>肯定发生了高并发]
```

解决:

并发有了:阻止并发到达DB,redis又没有key

redis是单进程单实例

setInx() -> 锁

<!--more-->

setInx() -> 锁

1.get key

2.setInx

3-1. ok ,去DB

3-2.false,sleep -> 1



问题:

1. 如果第一个人挂了?发生死锁

   可以设置锁的过期时间

2. 没挂,但是,锁超时了.....

   多线程,一个线程取库,一个线程监控,并延长时间

**自己实现分布式协调很麻烦**

#### 穿透

**<font color=MediumVioletRed>从业务接受查询的是你系统根本不存在的数据</font>**

```mermaid
graph LR
 	id0{业务} --> id1((client<br/>service))
 	id1 --> id2[redis<br/>缓存]
 	id1 --> id3[DB]
 	
 	id4[布隆过滤器] --> id5[client包含]
 	id4 --> id6[client只包含算法<br/> bitmap->redis<br/>无状态]
 	id4 --> id7[redis 集成布隆]
```

bloom过滤器问题:

- [x] 只能增加,不能删除

- [x] 布谷鸟过滤器

- [ ] 空key

#### 雪崩

**<font color=MediumVioletRed>大量的key同时失效,间接的造成大量的访问到达DB</font>**

```mermaid
graph LR
 	id0{业务} --> id1((client<br/>service))
 	id1 --> id2[redis<br/>缓存]
 	id1 --> id3[DB]
 	id4[随机过期时间] -.-> id5{零点}
 	id4 --> id6[时点性无关]
 	id5 --> id7[强依赖击穿方案]
 	id5 --> id8[业务层加判断,零点延时...]
 	style id5 fill:#0f0,stroke-width:2px,fill-opacity:0.5
```

#### 分布式锁

1setnx

2.过期时间

3.多线程(守护线程)延长过期



redisson

zookeeper 做分布式锁!

### API



```
127.0.0.1:6379> CONFIG GET *
127.0.0.1:6379> CONFIG SET protected-mode no
OK
```

