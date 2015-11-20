--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

--TASK
--Shopping cart abandonment analysis: For users who added products in
--their shopping carts but did not check out in the online store, find the average
--number of pages they visited during their sessions.

--IMPLEMENTATION NOTICE


-- Resources
ADD FILE ${hiveconf:QUERY_DIR}/q4_reducer2.py;
ADD FILE ${hiveconf:QUERY_DIR}/q4_sessionize.py;
--set hive.exec.parallel = true;


-- Part 1: re-construct a click session of a user  -----------
DROP view IF EXISTS ${hiveconf:TEMP_TABLE1};
CREATE view ${hiveconf:TEMP_TABLE1} AS
SELECT *
FROM 
(
  FROM 
  (
	SELECT
	  c.wcs_user_sk,
	  w.wp_type  ,
	 (wcs_click_date_sk*24*60*60 + wcs_click_time_sk) AS tstamp_inSec 
	FROM web_clickstreams c, web_page w 
	WHERE c.wcs_web_page_sk = w.wp_web_page_sk  
	AND   c.wcs_web_page_sk IS NOT NULL
	AND   c.wcs_user_sk     IS NOT NULL
	DISTRIBUTE BY wcs_user_sk SORT BY wcs_user_sk, tstamp_inSec -- "sessionize" reducer script requires the cluster by wcs_user_sk and sort by tstamp
  ) clicksAnWebPageType
  REDUCE
    wcs_user_sk,
    tstamp_inSec,
    wp_type
  USING 'python q4_sessionize.py ${hiveconf:q04_timeout_inSec}'
  AS (
    wp_type STRING,
    tstamp BIGINT,
    sessionid STRING)
) q04_tmp_sessionize
DISTRIBUTE BY sessionid SORT BY sessionid, tstamp  --required by "abandonment analysis script"
;


--Result  --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;
--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  averageNumberOfPages DECIMAL(15,2) 
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';


-- the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT avg(pagecount)
FROM (
  FROM ${hiveconf:TEMP_TABLE1} abbandonedSessions
  REDUCE 
    wp_type,
    tstamp,
    sessionid
  USING 'python q4_reducer2.py' AS (sessionid STRING, pagecount BIGINT)
)  abandonedShoppingCartsPageCounts
;

--cleanup --------------------------------------------
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};

