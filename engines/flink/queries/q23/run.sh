#!/usr/bin/env bash

#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

RESULT_TABLE1="${RESULT_TABLE}1"
RESULT_DIR1="$RESULT_DIR/$RESULT_TABLE1"
RESULT_TABLE2="${RESULT_TABLE}2"
RESULT_DIR2="$RESULT_DIR/$RESULT_TABLE2"

BINARY_PARAMS+=(--hiveconf RESULT_TABLE1=$RESULT_TABLE1 --hiveconf RESULT_DIR1=$RESULT_DIR1 --hiveconf RESULT_TABLE2=$RESULT_TABLE2 --hiveconf RESULT_DIR2=$RESULT_DIR2)


query_run_main_method () {
	QUERY_SCRIPT="$QUERY_DIR/$QUERY_NAME.sql"
	if [ ! -r "$QUERY_SCRIPT" ]
	then
		echo "SQL file $QUERY_SCRIPT can not be read."
		exit 1
	fi

    runCmdWithErrorCheck runEngineCmd -f "$QUERY_SCRIPT"
	return $?
}


query_run_clean_method () {
	runCmdWithErrorCheck runEngineCmd -e "DROP VIEW IF EXISTS $TEMP_TABLE; DROP TABLE IF EXISTS $RESULT_TABLE1; DROP TABLE IF EXISTS $RESULT_TABLE2;"
	return $?
}

query_run_validate_method () {
	# perform exact result validation if using SF 1, else perform general sanity check
	if [ "$BIG_BENCH_SCALE_FACTOR" -eq 1 ]
	then
		local VALIDATION_PASSED="1"
		local VALIDATION_RESULTS_FILENAME_1="$VALIDATION_RESULTS_FILENAME-1"
		local VALIDATION_RESULTS_FILENAME_2="$VALIDATION_RESULTS_FILENAME-2"

		if [ ! -f "$VALIDATION_RESULTS_FILENAME_1" ]
		then
			echo "Golden result set file $VALIDATION_RESULTS_FILENAME_1 not found"
			VALIDATION_PASSED="0"
		fi

		if diff -q "$VALIDATION_RESULTS_FILENAME_1" <(hadoop fs -cat "$RESULT_DIR1/*")
		then
			echo "Validation of $VALIDATION_RESULTS_FILENAME_1 passed: Query returned correct results"
		else
			echo "Validation of $VALIDATION_RESULTS_FILENAME_1 failed: Query returned incorrect results"
			VALIDATION_PASSED="0"
		fi

		if [ ! -f "$VALIDATION_RESULTS_FILENAME_2" ]
		then
			echo "Golden result set file $VALIDATION_RESULTS_FILENAME_2 not found"
			VALIDATION_PASSED="0"
		fi

		if diff -q "$VALIDATION_RESULTS_FILENAME_2" <(hadoop fs -cat "$RESULT_DIR2/*")
		then
			echo "Validation of $VALIDATION_RESULTS_FILENAME_2 passed: Query returned correct results"
		else
			echo "Validation of $VALIDATION_RESULTS_FILENAME_2 failed: Query returned incorrect results"
			VALIDATION_PASSED="0"
		fi

		if [ "$VALIDATION_PASSED" -eq 1 ]
		then
			echo "Validation passed: Query results are OK"
		else
			echo "Validation failed: Query results are not OK"
		fi
	else
		if [ `hadoop fs -cat "$RESULT_DIR1/*" | head -n 10 | wc -l` -ge 1 ]
		then
			echo "Validation passed: Query 1 returned results"
		else
			echo "Validation failed: Query 1 did not return results"
		fi
		if [ `hadoop fs -cat "$RESULT_DIR2/*" | head -n 10 | wc -l` -ge 1 ]
		then
			echo "Validation passed: Query 2 returned results"
		else
			echo "Validation failed: Query 2 did not return results"
		fi
	fi
}
