--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


--Cluster customers into book buddies/club groups based on their in
--store book purchasing histories.

-- IMPLEMENTATION NOTICE:
-- hive provides the input for the clustering program

-- The input format for the clustering is:
-- customer ID, sum of store sales in the item class ids 1, 3, 5, 7, 9, 11, 13, 15, 2, 4, 6, 8, 10, 14, 16
-- Fields are separated by a single space
-- Example:
-- 1 12 3 0 9 5 7 2 9 1 5 9 0 4 3 0\n


-- Resources

------ create input table for mahout --------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
CREATE TABLE ${hiveconf:TEMP_TABLE} (
  cid  INT,
  id1  INT,
  id3  INT,
  id5  INT,
  id7  INT,
  id9  INT,
  id11 INT,
  id13 INT,
  id15 INT,
  id2  INT,
  id4  INT,
  id6  INT,
  id8  INT,
  id10 INT,
  id14 INT,
  id16 INT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ' ' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR}';

INSERT INTO TABLE ${hiveconf:TEMP_TABLE}
SELECT
  ss.ss_customer_sk AS cid,
  count(CASE WHEN i.i_class_id=1  THEN 1 ELSE NULL END) AS id1,
  count(CASE WHEN i.i_class_id=3  THEN 1 ELSE NULL END) AS id3,
  count(CASE WHEN i.i_class_id=5  THEN 1 ELSE NULL END) AS id5,
  count(CASE WHEN i.i_class_id=7  THEN 1 ELSE NULL END) AS id7,
  count(CASE WHEN i.i_class_id=9  THEN 1 ELSE NULL END) AS id9,
  count(CASE WHEN i.i_class_id=11 THEN 1 ELSE NULL END) AS id11,
  count(CASE WHEN i.i_class_id=13 THEN 1 ELSE NULL END) AS id13,
  count(CASE WHEN i.i_class_id=15 THEN 1 ELSE NULL END) AS id15,
  count(CASE WHEN i.i_class_id=2  THEN 1 ELSE NULL END) AS id2,
  count(CASE WHEN i.i_class_id=4  THEN 1 ELSE NULL END) AS id4,
  count(CASE WHEN i.i_class_id=6  THEN 1 ELSE NULL END) AS id6,
  count(CASE WHEN i.i_class_id=8  THEN 1 ELSE NULL END) AS id8,
  count(CASE WHEN i.i_class_id=10 THEN 1 ELSE NULL END) AS id10,
  count(CASE WHEN i.i_class_id=14 THEN 1 ELSE NULL END) AS id14,
  count(CASE WHEN i.i_class_id=16 THEN 1 ELSE NULL END) AS id16
FROM store_sales ss
INNER JOIN item i ON ss.ss_item_sk = i.i_item_sk
WHERE i.i_category IN (${hiveconf:q26_i_category_IN})
AND ss.ss_customer_sk IS NOT NULL
GROUP BY ss.ss_customer_sk
HAVING count(ss.ss_item_sk) > ${hiveconf:q26_count_ss_item_sk}
--CLUSTER BY cid --cluster by preceeded by group by is silently ignored by hive but fails in spark
--no total ordering with ORDER BY required, further processed by clustering algorithm
;

-------------------------------------------------------------------------------
