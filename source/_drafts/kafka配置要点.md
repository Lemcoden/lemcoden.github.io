---
title: kafka配置要点
tags:
---

```
./bin/kafka-server-start.sh -daemon config/server.properties 
./bin/kafka-topics.sh  --bootstrap-server hadoop01:9092 --create --topic topic01 --partitions 3 --replication-factor 1
./bin/kafka-console-consumer.sh --bootstrap-server hadoop01:9092 --topic topic01 --group group1
./bin/kafka-console-producer.sh --broker-list hadoop01:9092 --topic topic01

```

