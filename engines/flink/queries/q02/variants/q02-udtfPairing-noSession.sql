--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


-- Find the top 30 products that are mostly viewed together with a given
-- product in online store. Note that the order of products viewed does not matter,
-- but "viewed together" relates to a click_session of a user with a session timeout of 60min.


-- NOTE THIS IMPLEMENTATION DOES NOT HONOR "sessions" but makes pairs over all views of a customer.

-- Resources
ADD JAR ${env:BIG_BENCH_QUERIES_DIR}/Resources/bigbenchqueriesmr.jar;
CREATE TEMPORARY FUNCTION makePairs AS 'io.bigdatabenchmark.v1.queries.udf.PairwiseUDTF';



--Result -------------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;
--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  item_sk_1 BIGINT,
  item_sk_2 BIGINT,
  cnt  BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';


-- the real query part

INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT  item_sk_1, item_sk_2, COUNT (*) AS cnt
FROM (
  --Make item "viewed together" pairs
    SELECT makePairs(sort_array(itemArray), false) AS (item_sk_1,item_sk_2)
	FROM (
		SELECT collect_list(wcs_item_sk) as itemArray --(_list= with dupplicates, _set = distinct)
		FROM web_clickstreams
		WHERE wcs_item_sk IS NOT NULL 
		AND wcs_user_sk IS NOT NULL
		GROUP BY wcs_user_sk
		HAVING array_contains(itemArray,  cast(${hiveconf:q02_item_sk} as BIGINT) ) -- eager filter out groups that dont contain the searched item
	) viewedItemsArray
) pairs
WHERE (   item_sk_1 = ${hiveconf:q02_item_sk}
       OR item_sk_2 = ${hiveconf:q02_item_sk}
	  )
GROUP BY item_sk_1, item_sk_2
ORDER BY cnt DESC, item_sk_1 ,item_sk_2
LIMIT  ${hiveconf:q02_limit};

