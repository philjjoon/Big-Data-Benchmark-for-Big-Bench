#!/usr/bin/env bash

#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

HDFS_RESULT_FILE="${RESULT_DIR}/cluster.txt"

query_run_main_method () {
	QUERY_SCRIPT="$QUERY_DIR/$QUERY_NAME.sql"
	if [ ! -r "$QUERY_SCRIPT" ]
	then
		echo "SQL file $QUERY_SCRIPT can not be read."
		exit 1
	fi

	#EXECUTION Plan:
	#step 1.  hive q20.sql		:	Run hive querys to extract kmeans input data
	#step 2.  mahout input		:	Generating sparse vectors
	#step 3.  mahout kmeans		:	Calculating k-means"
	#step 4.  mahout dump > hdfs/res:	Converting result and copy result do hdfs query result folder
	#step 5.  hive && hdfs 		:	cleanup.sql && hadoop fs rm MH

	MAHOUT_TEMP_DIR="$TEMP_DIR/mahout_temp"
	RETURN_CODE=0
	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 1 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 1/5: Executing hive queries"
		echo "tmp output: ${TEMP_DIR}"
		echo "========================="
		# Write input for k-means into ctable
		runCmdWithErrorCheck runEngineCmd -f "$QUERY_SCRIPT"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 2 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 2/5: Generating sparse vectors"
		echo "Command "mahout org.apache.mahout.clustering.conversion.InputDriver -i "${TEMP_DIR}" -o "${TEMP_DIR}/Vec" -v org.apache.mahout.math.RandomAccessSparseVector #-c UTF-8 
		echo "tmp output: ${TEMP_DIR}/Vec"
		echo "========================="

		runCmdWithErrorCheck mahout org.apache.mahout.clustering.conversion.InputDriver -i "${TEMP_DIR}" -o "${TEMP_DIR}/Vec" -v org.apache.mahout.math.RandomAccessSparseVector #-c UTF-8 
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 3 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 3/5: Calculating k-means"
		echo "Command "mahout kmeans -i "$TEMP_DIR/Vec" -c "$TEMP_DIR/init-clusters" -o "$TEMP_DIR/kmeans-clusters" -dm org.apache.mahout.common.distance.CosineDistanceMeasure -x 10 -ow -cl -xm $BIG_BENCH_ENGINE_HIVE_MAHOUT_EXECUTION
		echo "tmp output: $TEMP_DIR/kmeans-clusters"
		echo "========================="
		## Kmeans fails when running on HDFS and execution mode "mapreduce" https://issues.apache.org/jira/browse/MAHOUT-1658
		#runCmdWithErrorCheck mahout kmeans --tempDir "$MAHOUT_TEMP_DIR" -i "$TEMP_DIR/Vec" -c "$TEMP_DIR/init-clusters" -o "$TEMP_DIR/kmeans-clusters" -dm org.apache.mahout.common.distance.CosineDistanceMeasure -x 10 -k 8 -ow -cl -xm $BIG_BENCH_ENGINE_HIVE_MAHOUT_EXECUTION
		echo "upload initial clusters $QUERY_DIR/initialClusters from to hdfs: $TEMP_DIR/init-clusters"
     	hadoop fs -put -f $QUERY_DIR/init-clusters $TEMP_DIR/init-clusters

		runCmdWithErrorCheck mahout kmeans --tempDir "$MAHOUT_TEMP_DIR" -i "$TEMP_DIR/Vec" -c "$TEMP_DIR/init-clusters" -o "$TEMP_DIR/kmeans-clusters" -dm org.apache.mahout.common.distance.CosineDistanceMeasure -x 10 -ow -cl -xm $BIG_BENCH_ENGINE_HIVE_MAHOUT_EXECUTION
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 4 ]] ; then
		local CLUSTERS_OUT="`mktemp`"
		echo "========================="
		echo "$QUERY_NAME Step 4/5: Converting result and store in hdfs $HDFS_RESULT_FILE"
		echo "command: unCmdWithErrorCheck mahout clusterdump --tempDir "$MAHOUT_TEMP_DIR" -i "$TEMP_DIR"/kmeans-clusters/clusters-*-final -dm org.apache.mahout.common.distance.CosineDistanceMeasure -of TEXT -o $CLUSTERS_OUT ; hadoop fs -copyFromLocal $CLUSTERS_OUT \"$HDFS_RESULT_FILE\" "
		echo "========================="
		runCmdWithErrorCheck mahout clusterdump --tempDir "$MAHOUT_TEMP_DIR" -i "$TEMP_DIR"/kmeans-clusters/clusters-*-final -dm org.apache.mahout.common.distance.CosineDistanceMeasure -of TEXT -o $CLUSTERS_OUT
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		
		hadoop fs -copyFromLocal -f $CLUSTERS_OUT "$HDFS_RESULT_FILE"
		RETURN_CODE=$?
		rm -rf "$CLUSTERS_OUT"
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		
		#runCmdWithErrorCheck mahout seqdump -i $TEMP_DIR/Vec/ -c $TEMP_DIR/kmeans-clusters -o $TEMP_DIR/results -dm org.apache.mahout.common.distance.CosineDistanceMeasure -x 10 -k 8 -ow -cl
	fi

	if [[ -z "$DEBUG_QUERY_PART" || $DEBUG_QUERY_PART -eq 5 ]] ; then
		echo "========================="
		echo "$QUERY_NAME Step 5/5: Clean up"
		echo "========================="
		runCmdWithErrorCheck runEngineCmd -f "${QUERY_DIR}/cleanup.sql"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
		runCmdWithErrorCheck hadoop fs -rm -r -f "$TEMP_DIR"
		RETURN_CODE=$?
		if [[ $RETURN_CODE -ne 0 ]] ;  then return $RETURN_CODE; fi
	fi
}

query_run_clean_method () {
	runCmdWithErrorCheck runEngineCmd -e "DROP TABLE IF EXISTS $TEMP_TABLE; DROP TABLE IF EXISTS $RESULT_TABLE;"
	runCmdWithErrorCheck hadoop fs -rm -r -f "$HDFS_RESULT_FILE"
	return $?
}

query_run_validate_method () {
	# perform exact result validation if using SF 1, else perform general sanity check
	if [ "$BIG_BENCH_SCALE_FACTOR" -eq 1 ]
	then
		local VALIDATION_PASSED="1"

		if [ ! -f "$VALIDATION_RESULTS_FILENAME" ]
		then
			echo "Golden result set file $VALIDATION_RESULTS_FILENAME not found"
			VALIDATION_PASSED="0"
		fi

		if diff -q "$VALIDATION_RESULTS_FILENAME" <(hadoop fs -cat "$RESULT_DIR/*")
		then
			echo "Validation of $VALIDATION_RESULTS_FILENAME passed: Query returned correct results"
		else
			echo "Validation of $VALIDATION_RESULTS_FILENAME failed: Query returned incorrect results"
			VALIDATION_PASSED="0"
		fi
		if [ "$VALIDATION_PASSED" -eq 1 ]
		then
			echo "Validation passed: Query results are OK"
		else
			echo "Validation failed: Query results are not OK"
		fi
	else
		if [ `hadoop fs -cat "$RESULT_DIR/*" | head -n 10 | wc -l` -ge 1 ]
		then
			echo "Validation passed: Query returned results"
		else
			echo "Validation failed: Query did not return results"
		fi
	fi
}
