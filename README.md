Benchmarks Test
 - Standard Platform Test Suite
 - Hive TPC
 - Storm Topologies
 - Kafka Producer Consumer Throughput Test

Standard Platform Tests
-------------------------------
 - TeraSort benchmark suite 
   The goal of TeraSort is to sort n bytes of data as fast as possible using HDFS and Mapreduce layers to fullest.
 - TeraGen ( 500GB , 1TB, 2TB) 
 - TeraSort ( 500GB , 1TB, 2TB)
 - TeraValidate ( 500GB , 1TB, 2TB)
 - RandomWriter(Write and Sort) 
    A map/reduce program that writes 10GB of random data per node
 - DFS-IO Write and Read
   The TestDFSIO benchmark is a read and write test for HDFS
 - NNBench (Write, Read, Rename and Delete)
   NNBench is useful for load testing the NameNode hardware and configuration. It generates a lot of HDFS-related requests with normally very small “payloads” for the sole purpose of putting a high HDFS management stress on the NameNode
 - MRBench 
    MRBench loops a small job a number of times.
 - Data Load (Upload and Download)

########Execute Standard Platform Tests##########
```
	1) Copy the script awsbenchmark.sh on to user hdfs on client node.
	2) Configure Slots for AWS and BM , example:

		BM_NODE_COUNT=5
		BM_MAP_SLOTS=260
		BM_REDUCE_SLOTS=70

	3) Configure file sizes for Tera and other tests
	4) Enable or Disable the test at:

		TESTS_TO_EXECUTE=("RandomWriter" "DFS-IO Write" "DFS-IO Read" "NNBench Write" "NNBench Read" "NNBench Rename" "NNBench Delete" )

	5) Execute the script using Iterations and pre-upgrade or post-upgrade.

	nohup ./awsbenchmark.sh AWS pre-upgrade 1 &
	nohup ./awsbenchmark.sh AWS pre-upgrade 2 &
	nohup ./awsbenchmark.sh AWS pre-upgrade 3 &

6) Collect results from nohup.out 

	cat nohup.out |grep TIMER

7) Plot Graphs using XLS and Take Averages...

```

################################################


TPC-DS: Decision Support
----------------------------------

Classic EDW Dimensional model
Large fact tables
Complex queries

Interactive
Query 27: For all items sold in stores located in six states during a given year, find the average quantity, average list price, average list sales price, average coupon amount for a given gender, marital status, education and customer demographic. 
Query 84: List all customers living in a specified city, with an income between 2 values.

Reporting
Query 46: Compute the per-customer coupon amount and net profit of all "out of town" customers buying from stores located in 5 cities on weekends in three consecutive years. The customers need to fit the profile of having a specific dependent count and vehicle count.  For all these customers print the city they lived in at the time of purchase, the city in which the store is located, the coupon amount and net profit
Query 48: Calculate the total sales by different types of customers (e.g., based on marital status, education status), sales price and different combinations of state and sales profit.
Query 56: Compute the monthly sales amount for a specific month in a specific year, for items with three specific colors across all sales channels.  Only consider sales of customers residing in a specific time zone.  Group sales by item and sort output by sales amount.

Data Mining
Query 31: List the top five counties where the percentage growth in web sales is consistently higher compared to the percentage growth in store sales in the first three consecutive quarters for a given year.
Query 34: What is the monthly sales figure based on extended price for a specific month in a specific year, for manufacturers in a specific category in a given time zone.  Group sales by manufacturer identifier and sort output by sales amount, by channel, and give Total sales.
Query 73: Count the number of customers with specific buy potentials and whose dependent count to vehicle count ratio is larger than 1 and who in three consecutive years bought in stores located in 4 counties between 1 and 5 items in one purchase.  Only purchases in the first 2 days of the months are considered. 


#Running Hive TPC-DS and TPC-H
tpcds-setup.sh: this script runs test for tpcds, it generates data and loads it into hive tables.

To specify the amount of data pass the position parameter SCALE while running. Generally 1 maps to 1 GB
so ./tpcds-setup.sh 1000 will run test for 1 TB of data. This will be total data generated and not for individual table.

Example:
Build 1 TB of TPC-DS data: ./tpcds-setup 1000
Build 30 TB of text formatted TPC-DS data: FORMAT=textfile ./tpcds-setup 30000
Build 1 TB of TPC-H data: ./tpch-setup 1000

After running the dataload:

Run sample queries using following in the sample queries folder:

	sample_queries_tpcds/reports.sh &
	sample_queries_tpch/reports.sh &

######Execute TPC-DS and TPC-H on 200GB ORC Sequentially########
```
git clone https://github.com/hortonworks/hive-testbench

cd hive-aws

cd hive-testbench

nohup ./tpcds-setup 2000 & 

nohup ./sample_queries_tpcds/reports.sh &

nohup ./tpch-setup 2000 &

nohup ./sample_queries_tpch/reports.sh &
```
###############################################################

Storm Benchmarks
----------------------------------------------

Storm Topology - Simple resource benchmarks
3 types of Topology : Network , Memory and CPU Sensitive

The benchmark set contains 3 workloads. The category is "simple resource benchmark", the goal is to test how storm performs under pressure of certain resource. 
Simple resource benchmarks:
- sol, network sensitive
- rollingsort, memory sensitive
- wordcount, CPU sensitive

########Execute Storm Benchmarks#################
```
bin/stormbench -storm ${STORM_HOME}/bin/storm -jar ./target/storm-benchmark-${VERSION}-jar-with-dependencies.jar -conf ./conf/sol.yaml -c topology.workers=4 storm.benchmark.tools.Runner storm.benchmark.benchmarks.SOL

bin/stormbench -storm ${STORM_HOME}/bin/storm -jar ./target/storm-benchmark-${VERSION}-jar-with-dependencies.jar -conf ./conf/wordcount.yaml -c topology.workers=4 storm.benchmark.tools.Runner storm.benchmark.benchmarks.FileReadWordCount
 
bin/stormbench -storm ${STORM_HOME}/bin/storm -jar ./target/storm-benchmark-${VERSION}-jar-with-dependencies.jar -conf ./conf/rollingsort.yaml -c topology.workers=4 storm.benchmark.tools.Runner storm.benchmark.benchmarks.RollingSort
```
################################################# 

Kafka Benchmarks
-------------------------------------------------
Kafka Producer and Consumer Tests

The benchmark set contains Producer and Consumer test executing at various message size.
Producer and Consumer Together
100 bytes
5120 bytes
10000 bytes
100000 bytes
500000 bytes
1000000 bytes

100 bytes
Single thread no replication
Single-thread, async 3x replication
Single-thread, sync 3x replication
Throughput Versus Stored Data
Consumer throughput
End-to-end Latency (0 - 4000)

#######Execute Kafka Benchmarks############################
```
1) Copy the two kafka scripts to kafka user on kafka nodes.
2) Execute each one of them in nohup and grab stats from nohup.out and other files producer*.txt and consumer*.txt

nohup ./kafkabench_100bytes.sh &

nohup ./kafkaproducer.sh &
```
###########################################################
