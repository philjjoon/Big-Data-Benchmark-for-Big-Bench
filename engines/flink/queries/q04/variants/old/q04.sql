--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


--Shopping cart abandonment analysis: For users who added products in
--their shopping carts but did not check out in the online store, find the average
--number of pages they visited during their sessions.

-- Resources
ADD FILE ${hiveconf:QUERY_DIR}/q4_reducer1.py;
ADD FILE ${hiveconf:QUERY_DIR}/q4_reducer2.py;

-- Query parameters

-- Part 1: join webclickstreams with user, webpage and date -----------
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};
CREATE VIEW ${hiveconf:TEMP_TABLE1} AS
SELECT *
FROM (
  FROM (
    SELECT
      c.wcs_user_sk AS uid,
      c.wcs_item_sk AS item,
      w.wp_type     AS wptype,
      t.t_time+unix_timestamp(d.d_date,'yyyy-MM-dd') AS tstamp
    FROM web_clickstreams c
    JOIN web_page w ON (c.wcs_web_page_sk = w.wp_web_page_sk
      AND c.wcs_user_sk IS NOT NULL)
    JOIN date_dim d ON c.wcs_click_date_sk = d.d_date_sk
    JOIN time_dim t ON c.wcs_click_time_sk = t.t_time_sk
    CLUSTER BY uid
  ) q04_tmp_map_output
  REDUCE
    q04_tmp_map_output.uid,
    q04_tmp_map_output.item,
    q04_tmp_map_output.wptype,
    q04_tmp_map_output.tstamp
  USING 'python q4_reducer1.py ${hiveconf:q04_timeout}'
  AS (
    uid    BIGINT,
    item   BIGINT,
    wptype STRING,
    tstamp BIGINT,
    sessionid STRING)
) q04_tmp_sessionize
--ORDER BY uid, tstamp --ORDER BY is bad! total ordering ->only one reducer
--LIMIT 2500
CLUSTER BY sessionid,uid, tstamp
;


-- Part 2: Abandoned shopping carts ----------------------------------
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE2};
CREATE VIEW ${hiveconf:TEMP_TABLE2} AS
SELECT *
FROM (
  FROM ${hiveconf:TEMP_TABLE1} q04_tmp_map_output
  REDUCE q04_tmp_map_output.uid,
    q04_tmp_map_output.item,
    q04_tmp_map_output.wptype,
    q04_tmp_map_output.tstamp,
    q04_tmp_map_output.sessionid
  USING 'python q4_reducer2.py' AS (sid STRING, start_s BIGINT, end_s BIGINT)
) q04_tmp_npath
CLUSTER BY sid
;

--Result  --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;
--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  sid     STRING,
  s_pages BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';

-- the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT c.sid, COUNT (*) AS s_pages
FROM ${hiveconf:TEMP_TABLE2} c
JOIN ${hiveconf:TEMP_TABLE1} s ON s.sessionid = c.sid
GROUP BY c.sid
;


--cleanup --------------------------------------------
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE2};
