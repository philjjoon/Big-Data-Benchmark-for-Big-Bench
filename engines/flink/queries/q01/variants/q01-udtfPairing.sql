--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

--TASK
--Find products that are sold together frequently in given
--stores. Only products in certain categories sold in specific stores are considered,
--and "sold together frequently" means at least 50 customers bought these products 
--together in a transaction.

--IMPLEMENTATION NOTICE: 
-- "Market basket analyis"	Difficult part is to create pairs of "sold together" items within one sale
-- There are are several ways to to "basekting", implemented is way A)
-- A) collect all pairs per session (same sales_sk) in list and employ a UDF'S to produce pairwise combinations of all list elements
-- B) distribute by sales_sk end epmploy reducer streaming script to aggregate all items per session and produce the pairs
-- C) pure SQL: produce pairings by self joining on sales_sk and filtering out left.item_sk < right.item_sk

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
  pid1 BIGINT,
  pid2 BIGINT,
  cnt  BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';

-- the real query part
--Find the most frequent ones
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT  item_sk_1, item_sk_2, COUNT (*) AS cnt
FROM (
  --Make item "sold together" pairs
  
	-- combining collect_set + sorting + makepairs(array, noSelfParing) 
	-- ensuers we get no pairs with swapped places like: (12,24),(24,12). 
	-- We only produce tuples (12,24) ensuring that the smaller number is allways on the left side
    SELECT makePairs(sort_array(itemArray), false) AS (item_sk_1, item_sk_2) 
	FROM (
		SELECT collect_set(ss_item_sk) AS itemArray --(_list= with dupplicates, _set = distinct)
		FROM store_sales s, item i 
		-- Only products in certain categories sold in specific stores are considered,
		WHERE s.ss_item_sk = i.i_item_sk
		AND i.i_category_id in (${hiveconf:q01_i_category_id_IN})
		AND s.ss_store_sk in (${hiveconf:q01_ss_store_sk_IN})
		GROUP BY ss_ticket_number	
	) soldItemsPerTicket
) soldTogetherPairs
GROUP BY item_sk_1,item_sk_2
-- 'frequently'
HAVING cnt > ${hiveconf:q01_viewed_together_count}
ORDER BY cnt DESC, item_sk_1 ,item_sk_2
LIMIT  ${hiveconf:q02_limit};	
;

