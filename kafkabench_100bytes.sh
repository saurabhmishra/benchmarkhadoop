#!/bin/bash

logTime(){

  echo TIMER: "$@" at `date +"%m-%d-%y %H:%M:%S"`
}

echo "Delete Topics"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --delete --topic test2

echo "Create Topics"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --create --topic test2 --partitions 12 --replication-factor 3

echo "Single thread no replication"

logTime

#producer-performance [-h] --topic TOPIC --num-records NUM-RECORDS --record-size RECORD-SIZE --throughput THROUGHPUT --producer-props PROP-NAME=PROP-VALUE [PROP-NAME=PROP-VALUE ...]

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 50000000 --record-size 100 --throughput -1 --producer-props acks=
1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196

echo "Single-thread, async 3x replication"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 50000000 --record-size 100 --throughput -1 --producer-props acks=
1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196

echo "Single-thread, sync 3x replication"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 50000000 --record-size 100 --throughput -1 --producer-props acks=
-1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=64000

echo "Three Producers, 3x async replication"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 50000000 --record-size 100 --throughput -1 --producer-props acks=
1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196

echo "Throughput Versus Stored Data"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 100000000 --record-size 100 --throughput -1 --producer-props acks
=1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196

echo "Effect of message size"

logTime

for i in 10 100 1000 10000 100000;
do
echo ""
echo $i
/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records $((1000*1024*1024/$i)) --record-size $i --throughput -1 --produce
r-props acks=1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=128000
done;

echo "Consumer throughput"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-consumer-perf-test.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --messages 50000000 --topic test2 --threads 1

logTime

echo "End-to-end Latency"

logTime

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh kafka.tools.EndToEndLatency ip-10-0-0-27.us-west-2.compute.internal:6667 test2 5000 1 100

logTime

echo "Producer"

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test2 --num-records 50000000 --record-size 100 --throughput -1 --producer-props acks=
1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196  1> producer.txt 2>&1 &

logTime

echo "Consumer"

/usr/hdp/current/kafka-broker/bin/kafka-consumer-perf-test.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --messages 50000000 --topic test2 --threads 1 1> consumer.txt 2>&1 &

logTime
