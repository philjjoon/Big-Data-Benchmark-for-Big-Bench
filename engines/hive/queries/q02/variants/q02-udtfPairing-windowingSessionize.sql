--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

-- TASK:
-- Find the top 30 products that are mostly viewed together with a given
-- product in online store. Note that the order of products viewed does not matter,
-- and "viewed together" relates to a click_session of a user with a session timeout of 60min.

--IMPLEMENTATION NOTICE:
-- "Market basket analysis"   
-- First difficult part is to create pairs of "viewed together" items within one sale
-- There are are several ways to to "basketing", implemented is way A)
-- A) collect all pairs per session (same sales_sk) in list and employ a UDF'S to produce pairwise combinations of all list elements
-- B) distribute by sales_sk end employ reducer streaming script to aggregate all items per session and produce the pairs
-- C) pure SQL: produce pairings by self joining on sales_sk and filtering out left.item_sk < right.item_sk
--
-- The second difficulty is to reconstruct a users browsing session from the web_clickstreams  table
-- There are are several ways to to "sessionize", common to all is the creation of a unique virtual time stamp from the date and time serial
-- key's as we know they are both strictly monotonic increasing in order of time: (wcs_click_date_sk*24*60*60 + wcs_click_time_sk implemented is way A)
-- Implemented is way A)
-- A) sessionizeusing SQL-windowing functions => partition by user and  sort by virtual time stamp. 
--    Step1: compute time difference to preceding click_session
--    Step2: compute session id per user by defining a session as: clicks no father apart then q02_session_timeout_inSec
--    Step3: make unique session identifier <user_sk>_<user_session_ID>
-- B) sessionize by clustering on user_sk and sorting by virtual time stamp then feeding the output through a external reducer script
--    which linearly iterates over the rows,  keeps track of session id's per user based on the specified session timeout and makes the unique session identifier <user_sk>_<user_seesion_ID>


-- Resources
ADD JAR ${env:BIG_BENCH_QUERIES_DIR}/Resources/bigbenchqueriesmr.jar;
CREATE TEMPORARY FUNCTION makePairs AS 'io.bigdatabenchmark.v1.queries.udf.PairwiseUDTF';




-- SESSIONZIE by emplyoing windowing functions. 
-- Step1: compute time difference to preceeding click_session
-- Step2: compute session id per user by defining a session as: clicks no father apppart then q02_session_timeout_inSec
-- Step3: make unique session identifier <user_sk>_<user_seesion_ID>
drop view if exists ${hiveconf:TEMP_TABLE};
create  view  ${hiveconf:TEMP_TABLE} AS
--step 3:
select 	wcs_item_sk,
		concat(wcs_user_sk, '-', s_sum) AS sessionid
from 
(	--step2:
	select *, sum( (case when timediff > ${hiveconf:q02_session_timeout_inSec} then 1 else 0 end) ) over (partition by wcs_user_sk order by tstamp_inSec asc rows between unbounded preceding and current row) AS s_sum
	from 
	(	-- step1:
		select	*, tstamp_inSec - lag(tstamp_inSec, 1, 0) over (partition by wcs_user_sk	order by tstamp_inSec asc)  AS timediff
		from 
		(		-- make timestamp and select valid user sessions			
				SELECT 	wcs_user_sk ,
						wcs_item_sk, 
						(wcs_click_date_sk*24*60*60 + wcs_click_time_sk) AS tstamp_inSec 
				FROM web_clickstreams
				WHERE wcs_item_sk IS NOT NULL 
				AND   wcs_user_sk IS NOT NULL
		) clicks_and_timestamp
	) clicks_and_timestamp_diff_timeout 
)clicks_and_timestamp_create_sessionid
;



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
	-- combining collect_set + sorting + makepairs(array, noSelfParing) 
	-- ensuers we get no pairs with swapped places like: (12,24),(24,12). 
	-- We only produce tuples (12,24) ensuring that the smaller number is allways on the left side
    SELECT makePairs(sort_array(itemArray), false) AS (item_sk_1,item_sk_2)
	FROM (
		SELECT collect_set(wcs_item_sk) as itemArray --(_list= with dupplicates, _set = distinct)
		FROM  ${hiveconf:TEMP_TABLE}
		GROUP BY sessionid
		HAVING array_contains(itemArray,  cast(${hiveconf:q02_item_sk} as BIGINT) ) -- eager filter out groups that dont contain the searched item
	) viewedItemsArray
) pairs
WHERE (   item_sk_1 = ${hiveconf:q02_item_sk}  --Note that the order of products viewed does not matter,
       OR item_sk_2 = ${hiveconf:q02_item_sk}
	  )
GROUP BY item_sk_1, item_sk_2
ORDER BY cnt DESC, item_sk_1 ,item_sk_2
LIMIT  ${hiveconf:q02_limit};		

-- cleanup		
drop view if exists ${hiveconf:TEMP_TABLE};

