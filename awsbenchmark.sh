#!/bin/bash

#set -x
#set -v

TESTS_TO_EXECUTE=("TeraGen" "TeraSort" "RandomWriter" "DFS-IO Write" "DFS-IO Read" "NNBench Write" "NNBench Read" "NNBench Rename" "NNBench Delete" "MRBench")
#TESTS_TO_EXECUTE=("TeraGen" "TeraSort"  "DFS-IO Write" "DFS-IO Read" "NNBench Write" "NNBench Read" "MRBench")

logTime(){

  echo TIMER: "$@" at `date +"%m-%d-%y %H:%M:%S"`
}

usage (){
  echo "$0 <cluster name LOCAL|AWS|BM> <execution stage pre-upgrade|post-upgrade> [iteration number]"
  exit 1
}

backupOldData(){
  echo ""
  hadoop fs -mv $1 $1-` hadoop fs -ls $1 | egrep "^[-d]" | head -1 | awk '{printf $6 " " $7}' | (tr ' ' '_') | (tr ':' '_')`
  echo ""

}


 isTestEnabled() {
   field=$1
   for f in $TESTS_TO_EXECUTE
    do
        if [ "${field}" == "${f}" ]
         then
            echo "y"
            return 0
        fi
    done

    echo "y"
    return 0
}




EXECUTION_STAGE=`echo $2 | tr '[:upper:]' '[:lower:]'`
CLUSTER_NAME=`echo $1 | tr '[:lower:]' '[:upper:]'`

if [ "$#" -lt 2 ] ; then
  usage
  elif [ "$CLUSTER_NAME" != "LOCAL" ] && [ "$CLUSTER_NAME" != "AWS" ] && [ "$CLUSTER_NAME" != "BM" ] ; then
  usage
  elif [ "$EXECUTION_STAGE" != "pre-upgrade" ] && [ "$EXECUTION_STAGE" != "post-upgrade" ] ; then
  usage
fi

if [ "$#" -gt 2 ] ; then
ITERATION=$3
else
ITERATION=1
fi


logTime "$0 Script execution began ITERATION $ITERATION"


## Cluster specific configs. Identify these for all ENVs

# Terasort Configs
LOCAL_TERASORT_VOLUME_IN_GB=(5)
AWS_TERASORT_VOLUME_IN_GB=(500 1000 2000)
BM_TERASORT_VOLUME_IN_GB=(500 1000 2000)

# DFSIO configs
LOCAL_DFS_IO_FILE_SIZE=(128)
AWS_DFS_IO_FILE_SIZE=(128 1536 7680)
BM_DFS_IO_FILE_SIZE=(128 1536 7680)
DFS_IO_REP_FACTORS=(3)

# NN Bench configs
LOCAL_NN_BENCH_FILES_IN_BATCH=(1)
AWS_NN_BENCH_FILES_IN_BATCH=(10 100 1000)
BM_NN_BENCH_FILES_IN_BATCH=(10 100 1000)

# NN Bench configs
LOCAL_MR_BENCH_TOTAL_RUNS=1
AWS_MR_BENCH_TOTAL_RUNS=50
BM_MR_BENCH_TOTAL_RUNS=50

MR_BENCH_SLOT_MULTIPLIER=(1)
DATA_LOAD_TEST_VOLUME_IN_GB=(1 5 10)
SCHEDULER_QUEUE_NAME=default




## Cluster details. Set these once for all ENVs

LOCAL_NODE_COUNT=1
LOCAL_MAP_SLOTS=1
LOCAL_REDUCE_SLOTS=1

AWS_NODE_COUNT=5
AWS_MAP_SLOTS=260
AWS_REDUCE_SLOTS=70

BM_NODE_COUNT=5
BM_MAP_SLOTS=260
BM_REDUCE_SLOTS=70


## Dynamic values based on cluster
VAR_NODE_COUNT=${CLUSTER_NAME}"_NODE_COUNT"
CLUSTER_NODE_COUNT=`echo "${!VAR_NODE_COUNT}"`

VAR_MAP_SLOTS=${CLUSTER_NAME}"_MAP_SLOTS"
CLUSTER_MAP_SLOTS=`echo "${!VAR_MAP_SLOTS}"`

VAR_REDICE_SLOTS=${CLUSTER_NAME}"_REDUCE_SLOTS"
CLUSTER_REDUCE_SLOTS="`echo ${!VAR_REDICE_SLOTS}`"

VAR_TERASORT_VOLUME_IN_GB=${CLUSTER_NAME}"_TERASORT_VOLUME_IN_GB[*]"
TERASORT_VOLUME_IN_GB="`echo ${!VAR_TERASORT_VOLUME_IN_GB}`"
CLUSTER_MAP_SLOTS_PER_HOST=$(( $CLUSTER_MAP_SLOTS / $CLUSTER_NODE_COUNT ))

VAR_DFS_IO_FILE_SIZE=${CLUSTER_NAME}"_DFS_IO_FILE_SIZE[*]"
DFS_IO_FILE_SIZE="`echo ${!VAR_DFS_IO_FILE_SIZE}`"

VAR_NN_BENCH_FILES_IN_BATCH=${CLUSTER_NAME}"_NN_BENCH_FILES_IN_BATCH[*]"
NN_BENCH_FILES_IN_BATCH="`echo ${!VAR_NN_BENCH_FILES_IN_BATCH}`"

VAR_MR_BENCH_TOTAL_RUNS=${CLUSTER_NAME}"_MR_BENCH_TOTAL_RUNS"
MR_BENCH_TOTAL_RUNS="`echo ${!VAR_MR_BENCH_TOTAL_RUNS}`"


## MR Job Options

CLUSTER_OPTS=" -D mapred.map.tasks=$CLUSTER_MAP_SLOTS -D mapred.reduce.tasks=$CLUSTER_REDUCE_SLOTS -D mapred.job.queue.name=$SCHEDULER_QUEUE_NAME -D mapreduce.job.queuename=$SCHEDULER_QUEUE_NAME"
DEFAULT_OPTS=" -D mapred.map.tasks.speculative.execution=false -D mapred.reduce.tasks.speculative.execution=false "
COMPRESSION_OPTS=" -D mapred.compress.map.output=true -D mapred.map.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec  -D mapred.compress.output=true -D mapred.output.compression.type=BLOCK "
SNAPPY_OPTS=$COMPRESSION_OPTS" -D mapred.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec"
LZO_OPTS=$COMPRESSION_OPTS" -D mapred.output.compression.codec=com.hadoop.compression.lzo.LzopCodec"
GZIP_OPTS=$COMPRESSION_OPTS" -D mapred.output.compression.codec=org.apache.hadoop.io.compress.GzipCodec"


NN_BENCH_WAIT_TIME_SEC=120

### Set up dirs ###
hadoop fs -mkdir -p /benchmarks/
hadoop fs -mkdir -p /users/hdfs/upgrade/
hadoop fs -mkdir -p /users/mapred/upgrade/
hadoop fs -mkdir -p /users/hdfs/upgrade/$EXECUTION_STAGE/data/output
hadoop fs -mkdir -p /users/mapred/upgrade/$EXECUTION_STAGE/data/input/terasort
hadoop fs -mkdir -p /users/mapred/upgrade/$EXECUTION_STAGE/data/input/randomwrite

hadoop fs -chmod -R 777 /users/

  ### TeraGen (only during pre upgrade) ###

  for VOLUME in $TERASORT_VOLUME_IN_GB
  do
      TERASORT_NUMBER_OF_RECORDS=$(( $VOLUME * 10000000 ))

TEST_NAME="TeraGen"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

  if [ "$EXECUTION_STAGE" == "pre-upgrade" ]  ; then


      OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/input/TeraSort_TeraGen_iteration_${ITERATION}_volume_${VOLUME}
      #backupOldData $OUT_DIR

      logTime Starting TeraSort_TeraGen_iteration_${ITERATION}_volume_${VOLUME}
      hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar teragen $CLUSTER_OPTS $DEFAULT_OPTS $SNAPPY_OPTS $TERASORT_NUMBER_OF_RECORDS $OUT_DIR
      logTime Finished TeraSort_TeraGen_iteration_${ITERATION}_volume_${VOLUME}
  fi
else
 echo "Skippig test $TEST_NAME"
fi


    ### TeraSort ###

TEST_NAME="TeraSort"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

    OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/TeraSort_TeraSort_iteration_${ITERATION}_volume_${VOLUME}
    #backupOldData $OUT_DIR
    TERAGEN_OUT_DIR=$OUT_DIR

    logTime Starting TeraSort_TeraSort_iteration_${ITERATION}_volume_${VOLUME}
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar terasort  $CLUSTER_OPTS $DEFAULT_OPTS $SNAPPY_OPTS /users/hdfs/upgrade/pre-upgrade/data/input/TeraSort_TeraGen_iteration_${ITERATION}_volume_${VOLUME} $OUT_DIR
    logTime Finished TeraSort_TeraSort_iteration_${ITERATION}_volume_${VOLUME}

    ### TeraValidate ###
    #OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/TeraSort_TeraValidate_iteration_${ITERATION}_volume_${VOLUME}
    ##backupOldData $OUT_DIR
    TERASORT_OUT_DIR=$OUT_DIR
    OUT_VALID_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/TeraSort_TeraValidate_iteration_${ITERATION}_volume_${VOLUME}

    logTime Starting TeraSort_TeraValidate_iteration_${ITERATION}_volume_${VOLUME}
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar teravalidate  $CLUSTER_OPTS $DEFAULT_OPTS $SNAPPY_OPTS $TERASORT_OUT_DIR $OUT_VALID_DIR
    logTime Finished TeraSort_TeraValidate_iteration_${ITERATION}_volume_${VOLUME}
else
 echo "Skippig test $TEST_NAME"
fi

  done


  ### RandomWriter ###



TEST_NAME="RandomWriter"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then



  OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/ouptut/RandomWriter_Write_iteration_${ITERATION}
  #backupOldData $OUT_DIR
  RANDOM_WRITER_OUT_DIR=$OUT_DIR

  logTime Starting RandomWriter_Write_iteration_${ITERATION}
  hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar randomwriter  $CLUSTER_OPTS $DEFAULT_OPTS $SNAPPY_OPTS -D test.randomwriter.maps_per_host=$CLUSTER_MAP_SLOTS_PER_HOST -D test.randomwrite.bytes_per_map=1073741824 -D test.randomwrite.min
_key=10 -D test.randomwrite.max_key=1000 -D test.randomwrite.min_value=0 -D test.randomwrite.max_value=20000 $OUT_DIR
  logTime Finished RandomWriter_Write_iteration_${ITERATION}

  IN_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/ouptut/RandomWriter_Write_iteration_${ITERATION}
  ### Sort for fair comparison sort only pre-upgrade data ###
  OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/RandomWriter_Sort_iteration_${ITERATION}
  #backupOldData $OUT_DIR

  logTime Starting RandomWriter_Sort_iteration_${ITERATION}
  hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar sort  $CLUSTER_OPTS $DEFAULT_OPTS $SNAPPY_OPTS $IN_DIR $OUT_DIR
  logTime Finished RandomWriter_Sort_iteration_${ITERATION}

else
 echo "Skippig test $TEST_NAME"
fi


    ### DFSIO  Test ###


TEST_NAME="DFS-IO Write"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

  for REP_FACTOR in $DFS_IO_REP_FACTORS
  do
  for FILE_SIZE in $DFS_IO_FILE_SIZE
  do
   hdfs dfs -mkdir -p /benchmarks/TestDFSIO
    ## Clean ##
    logTime Starting DFSIO_Clean_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar TestDFSIO  -clean
    logTime Finished DFSIO_Clean_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}

    ## Write ##
    logTime Starting DFSIO_Write_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar TestDFSIO  $CLUSTER_OPTS $DEFAULT_OPTS  -write -nrFiles $CLUSTER_MAP_SLOTS -fileSize $FILE_SIZE
    logTime Finished DFSIO_Write_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}

	## Move the data to back to backup location
    hadoop fs -mv /benchmarks/TestDFSIO /users/hdfs/upgrade/$EXECUTION_STAGE/data/output/DFSIO_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}
  done
  done
else
 echo "Skippig test $TEST_NAME"
fi


TEST_NAME="DFS-IO Read"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

 for REP_FACTORS in $DFS_IO_REP_FACTORS
  do
  for FILE_SIZE in $DFS_IO_FILE_SIZE
  do

  ## Read ##

  	## Get the pre upgrade data
    hadoop fs -mv /users/hdfs/upgrade/pre-upgrade/data/output/DFSIO_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR} /benchmarks/TestDFSIO

    logTime Starting DFSIO_Read_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar TestDFSIO $CLUSTER_OPTS $DEFAULT_OPTS  -read -nrFiles $CLUSTER_MAP_SLOTS -fileSize $FILE_SIZE
    logTime Finished DFSIO_Read_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}

	## Move the data to back to backup location
    hadoop fs -mv /benchmarks/TestDFSIO /users/hdfs/upgrade/pre-upgrade/data/output/DFSIO_iteration_${ITERATION}_filesize_${FILE_SIZE}_repfactor_${REP_FACTOR}
  done
  done
else
 echo "Skippig test $TEST_NAME"
fi

  ### NN Bench Test ###

  NN_BENCH_TOTAL_FILES=$NN_BENCH_FILES_IN_BATCH

  for FILES_IN_BATCH in $NN_BENCH_FILES_IN_BATCH
  do

    TEST_NAME="NNBench Write"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

    ## Write ##
    OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/NNBench_CreateWrite_iteration_${ITERATION}_files_${FILES_IN_BATCH}
    #backupOldData $OUT_DIR
    NN_BENCH_WRITE_DIR=$OUT_DIR


    logTime Starting NNBench_CreateWrite_iteration_${ITERATION}_files_${FILES_IN_BATCH}
    curr_time=`date +%s`
    next_time=`bc <<< "$curr_time - ($curr_time % $NN_BENCH_WAIT_TIME_SEC) + $NN_BENCH_WAIT_TIME_SEC"`
    #echo The job will start execution at `date -r $next_time  +"%m-%d-%y %H:%M:%S"`
    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar nnbench -operation create_write \
    -maps $CLUSTER_MAP_SLOTS -reduces 1 -blockSize 1 -bytesToWrite 0 -numberOfFiles $FILES_IN_BATCH \
    -replicationFactorPerFile 3 -readFileAfterOpen false \
    -baseDir $NN_BENCH_WRITE_DIR
    logTime Finished NNBench_CreateWrite_iteration_${ITERATION}_files_${FILES_IN_BATCH}
else
 echo "Skippig test $TEST_NAME"
fi

    TEST_NAME="NNBench Read"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

    ## Read ##

    logTime Starting NNBench_OpenRead_iteration_${ITERATION}_files_${FILES_IN_BATCH}
    curr_time=`date +%s`
    next_time=`bc <<< "$curr_time - ($curr_time % $NN_BENCH_WAIT_TIME_SEC) + $NN_BENCH_WAIT_TIME_SEC"`
    #echo The job will start execution at `date -r $next_time  +"%m-%d-%y %H:%M:%S"`

    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar nnbench -operation open_read \
    -maps $CLUSTER_MAP_SLOTS -reduces 1 -blockSize 1  -numberOfFiles $FILES_IN_BATCH \
    -readFileAfterOpen false \
    -baseDir $NN_BENCH_WRITE_DIR
    logTime Finished NNBench_OpenRead_iteration_${ITERATION}_files_${FILES_IN_BATCH}
else
 echo "Skippig test $TEST_NAME"
fi


    TEST_NAME="NNBench Rename"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

    ## Rename ##

    logTime Starting NNBench_Rename_iteration_${ITERATION}_files_${FILES_IN_BATCH}
    curr_time=`date +%s`
    next_time=`bc <<< "$curr_time - ($curr_time % $NN_BENCH_WAIT_TIME_SEC) + $NN_BENCH_WAIT_TIME_SEC"`
    echo The job will start execution at `date -r $next_time  +"%m-%d-%y %H:%M:%S"`

    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar nnbench -operation rename \
    -maps $CLUSTER_MAP_SLOTS -reduces 1 -blockSize 1  -numberOfFiles $FILES_IN_BATCH \
    -readFileAfterOpen false \
    -baseDir $NN_BENCH_WRITE_DIR
    logTime Finished NNBench_Rename_iteration_${ITERATION}_files_${FILES_IN_BATCH}
else
 echo "Skippig test $TEST_NAME"
fi



    TEST_NAME="NNBench Delete"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

    ## Delete ##

    logTime Starting NNBench_Delete_iteration_${ITERATION}_files_${FILES_IN_BATCH}
    curr_time=`date +%s`
    next_time=`bc <<< "$curr_time - ($curr_time % $NN_BENCH_WAIT_TIME_SEC) + $NN_BENCH_WAIT_TIME_SEC"`
    echo The job will start execution at `date -r $next_time  +"%m-%d-%y %H:%M:%S"`

    hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar nnbench -operation delete \
    -maps $CLUSTER_MAP_SLOTS -reduces 1 -blockSize 1  -numberOfFiles $FILES_IN_BATCH \
    -readFileAfterOpen false \
    -baseDir $NN_BENCH_WRITE_DIR \
    -renameExecuted true
    logTime Finished NNBench_Delete_iteration_${ITERATION}_files_${FILES_IN_BATCH}

else
 echo "Skippig test $TEST_NAME"
fi

  done



  ### MR Bench Test ###

    TEST_NAME="MRBench"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

  for SLOT_MULTIPLIER in $MR_BENCH_SLOT_MULTIPLIER
  do

   MAPPERS=$(( $CLUSTER_MAP_SLOTS * $SLOT_MULTIPLIER ))
   REDUCERS=$(( $CLUSTER_REDUCE_SLOTS * $SLOT_MULTIPLIER ))

   OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/MRBench_1LineJob_iteration_${ITERATION}_slotMultiplier_${SLOT_MULTIPLIER}
   #backupOldData $OUT_DIR


   logTime Starting MRBench_1LineJob_iteration_${ITERATION}_slotMultiplier_${SLOT_MULTIPLIER}
   hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient.jar mrbench  \
   -baseDir $OUT_DIR \
   -numRuns $MR_BENCH_TOTAL_RUNS  -maps $MAPPERS -reduces $REDUCERS  -inputLines 1
   logTime Finished MRBench_1LineJob_iteration_${ITERATION}_slotMultiplier_${SLOT_MULTIPLIER}


  done
  else
 echo "Skippig test $TEST_NAME"
fi



  ### DATA LOAD TEST  ###

      TEST_NAME="Data Load"
if [ $(isTestEnabled  "$TEST_NAME") == "y" ]; then

  for TEST_VOLUME in $DATA_LOAD_TEST_VOLUME_IN_GB
  do

   if [ "$EXECUTION_STAGE" == "pre-upgrade" ] && [ $ITERATION -eq  1 ]
    then
   mkdir -p ./data/
   openssl rand -out ./data/data_file_${TEST_VOLUME}GB -base64 $(( 2**10 * 3/4 * $TEST_VOLUME ))
   fi


   OUT_DIR=/users/hdfs/upgrade/$EXECUTION_STAGE/data/output/DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB
   #backupOldData $OUT_DIR


   hadoop fs -mkdir /users/hdfs/upgrade/$EXECUTION_STAGE/data/output/DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB

   logTime Starting DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB
   hadoop fs -put ./data/data_file_${TEST_VOLUME}GB /users/hdfs/upgrade/$EXECUTION_STAGE/data/output/DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB/
   logTime Finished DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB


   logTime Starting DataLoad_Download_iteration_${ITERATION}_${TEST_VOLUME}GB
   hadoop fs -get /users/hdfs/upgrade/$EXECUTION_STAGE/data/output/DataLoad_Upload_iteration_${ITERATION}_${TEST_VOLUME}GB/data_file_${TEST_VOLUME}GB ./tmpfile
   logTime Finished DataLoad_Download_iteration_${ITERATION}_${TEST_VOLUME}GB/

  done
else
 echo "Skippig test $TEST_NAME"
fi

logTime "$0 Script execution completed ITERATION $ITERATION"
