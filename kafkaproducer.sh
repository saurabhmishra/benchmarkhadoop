#!/bin/bash

logTime(){

  echo TIMER: "$@" at `date +"%m-%d-%y %H:%M:%S"`
}

array=( 100 1000 5120 10000 100000 500000 1000000 )

for i in "${array[@]}"

do

/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --create --topic test$i --partitions 12 --replication-factor 3

logTime

echo "Producer"

/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh org.apache.kafka.tools.ProducerPerformance --topic test$i --num-records $((1000*1024*1024/$i)) --record-size $i --throughput -1 --produc
er-props acks=1 bootstrap.servers=ip-10-0-0-27.us-west-2.compute.internal:6667 buffer.memory=67108864 batch.size=8196  1> producer$i.txt 2>&1 &

logTime

echo "Consumer"

/usr/hdp/current/kafka-broker/bin/kafka-consumer-perf-test.sh --zookeeper ip-10-0-0-27.us-west-2.compute.internal:2181 --messages $((1000*1024*1024/$i)) --topic test$i --threads 1 1> consum
er$i.txt 2>&1 &

logTime

done
