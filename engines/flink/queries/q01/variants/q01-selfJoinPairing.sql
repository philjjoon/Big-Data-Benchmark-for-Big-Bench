--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


--Find products that are sold together frequently in given
--stores. Only products in certain categories sold in specific stores are considered,
--and "sold together frequently" means at least 50 customers bought these products 
--together in a transaction.

-- Resources

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
SELECT 
	t1.pid AS item1,
	t2.pid AS item2,
	count(1) AS cnt
 FROM (
 SELECT DISTINCT s.ss_ticket_number AS purchaseID , s.ss_item_sk AS pid
    FROM store_sales s, item i 
	-- Only products in certain categories sold in specific stores are considered,
	WHERE s.ss_item_sk = i.i_item_sk
    AND i.i_category_id in (${hiveconf:q01_i_category_id_IN})
    AND s.ss_store_sk in (${hiveconf:q01_ss_store_sk_IN})
    CLUSTER BY purchaseID
)t1 , 
(
 SELECT DISTINCT s.ss_ticket_number AS purchaseID , s.ss_item_sk AS pid
    FROM store_sales s, item i 
	-- Only products in certain categories sold in specific stores are considered,
	WHERE s.ss_item_sk = i.i_item_sk
    AND i.i_category_id in (${hiveconf:q01_i_category_id_IN})
    AND s.ss_store_sk in (${hiveconf:q01_ss_store_sk_IN})
    CLUSTER BY purchaseID
)t2
--self join "sold together"
WHERE t1.purchaseID = t2.purchaseID
 -- we do < to avoid dupplicates like: (10,22), (22,10). 
AND t1.pid < t2.pid
GROUP BY t1.pid, t2.pid
-- 'frequently'
HAVING cnt > ${hiveconf:q01_viewed_together_count}
ORDER BY cnt DESC, item_sk_1 ,item_sk_2
LIMIT  ${hiveconf:q02_limit};	
;

