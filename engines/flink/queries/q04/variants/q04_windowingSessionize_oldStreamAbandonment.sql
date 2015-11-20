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


--set hive.exec.parallel = true;


-- alternative way to "sessionize" the web clickstreams by using windowing fuctions
drop view if exists  ${hiveconf:TEMP_TABLE1};
create view  ${hiveconf:TEMP_TABLE1} AS
select 	wp_type,
		tstamp,
		concat(wcs_user_sk, '-', s_sum) sessionid
from 
(
	select	*,
			sum( (case when timediff > ${hiveconf:q04_session_timeout_inSec} then 1 else 0 end) ) over (partition by wcs_user_sk order by tstamp asc rows between unbounded preceding and current row) s_sum
	from 
	(
		select	*,
				tstamp - lag(tstamp, 1, 0) over (partition by wcs_user_sk	order by tstamp asc) timediff
		from 
		(
				SELECT	wcs_user_sk ,
						w.wp_type , 
						(wcs_click_date_sk*24*60*60 + wcs_click_time_sk) AS tstamp 
				FROM web_clickstreams c, web_page w 
				WHERE c.wcs_web_page_sk = w.wp_web_page_sk  
				AND   c.wcs_web_page_sk IS NOT NULL
				AND   c.wcs_user_sk IS NOT NULL
		) clicks_and_timestamp	
	) clicks_and_timestamp_diff_timeout 
)clicks_and_timestamp_create_sessionid
DISTRIBUTE BY sessionid SORT BY sessionid, tstamp --required by "abandonment analysis script"
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

