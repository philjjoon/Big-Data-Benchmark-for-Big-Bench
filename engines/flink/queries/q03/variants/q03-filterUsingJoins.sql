--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


--Find the last 5 products that are mostly viewed before a given product
--was purchased online. Only products in certain categories and viewed within 10
--days before the purchase date are considered. Show the top 100 products ranked by number of views.


set viewOrTable=view;
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_userClicks;
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_purchases;
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_viewed;

-- clicks have skew in data( some items and users are high frequency), wcs_sales_sk can be null
-- "10 days before the purchase" => we have to consider clicks of the same user outside of his session
create ${hiveconf:viewOrTable}  if not exists  ${hiveconf:TEMP_TABLE}_userClicks AS
SELECT 	wcs_user_sk ,
		wcs_sales_sk,
	   (wcs_click_date_sk*24*60*60 + wcs_click_time_sk) AS click_timestamp ,
		wcs_item_sk                   
FROM web_clickstreams w
WHERE wcs_user_sk IS NOT NULL -- only select clickstreams we can further analyze: requires a known visitor: user_sk != null but
--AND wcs_sales_sk IS NOT NULL 
--GROUP BY wcs_user_sk
--cluster by wcs_sales_sk, click_timestamp, wcs_item_sk
--cluster by wcs_user_sk, wcs_sales_sk, click_timestamp, wcs_item_sk
cluster by wcs_sales_sk --mitigate skew and optimize for join on wcs_sales_sk in later temporary tables
;


--items purchased per user (without viewed items)
create ${hiveconf:viewOrTable}  if not exists  ${hiveconf:TEMP_TABLE}_purchases AS
SELECT wcs_user_sk, 
	   wcs_sales_sk,
	   click_timestamp 
	   --wcs_item_sk    
            
FROM  ${hiveconf:TEMP_TABLE}_userClicks, web_sales
WHERE wcs_sales_sk = ws_order_number
AND wcs_sales_sk IS NOT NULL --is a purchase
AND ws_item_sk = wcs_item_sk
AND wcs_item_sk IN ( ${hiveconf:q03_purchased_item_IN} )  --purchased a specific items
--cluster by wcs_sales_sk, click_timestamp, wcs_item_sk
--cluster by wcs_user_sk, wcs_sales_sk, click_timestamp, wcs_item_sk
--cluster by wcs_sales_sk
cluster by wcs_user_sk
;



-- items viewed per user (without "purchased") - perhaps we can ignore this and consider all items, including purchased, as "viewed before"
create  ${hiveconf:viewOrTable} if not exists  ${hiveconf:TEMP_TABLE}_viewed AS
SELECT 	wcs_user_sk ,
		--wcs_sales_sk,
		click_timestamp,
		wcs_item_sk      	             
FROM  
    (
		SELECT  wcs_user_sk ,
				wcs_sales_sk,
				click_timestamp,
				wcs_item_sk 
		FROM ${hiveconf:TEMP_TABLE}_userClicks , item i
		WHERE i.i_item_sk  = wcs_item_sk
		AND i.i_category_id IN (${hiveconf:q03_purchased_item_category_IN}) --viewed items from specific categories
    ) clicked_items_in_category
LEFT OUTER JOIN web_sales ws ON (wcs_sales_sk = ws_order_number AND  ws_item_sk = wcs_item_sk)
WHERE ws.ws_item_sk IS NULL --IS NULL => fulfilling the "not in" condition to filter out items that where bought (only interested in viewed items). Hint: on left outer join, columns not fullfilling the conditions are null
--cluster by wcs_sales_sk, click_timestamp, wcs_item_sk
--cluster by wcs_user_sk, wcs_sales_sk, click_timestamp, wcs_item_sk
--cluster by wcs_sales_sk
cluster by wcs_user_sk

;



--Result -------------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;
--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  viewedItem BIGINT,
  cnt        BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';

-- the real query part
--explain
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT 	viewedItem ,
		count(*) as cnt
FROM(
	SELECT 	 
			-- p.wcs_user_sk as user_sk,
			-- p.wcs_sales_sk as sales_sk,
			-- p.wcs_item_sk as purchasedItem,
			-- p.click_timestamp as purchasedDate,
			v.wcs_item_sk as viewedItem,
			-- v.click_timestamp as viewedDate,
			ROW_NUMBER() over(partition by p.wcs_sales_sk order by  v.click_timestamp desc) rowNumber
	FROM  ${hiveconf:TEMP_TABLE}_purchases p,  ${hiveconf:TEMP_TABLE}_viewed v 
	WHERE  p.wcs_user_sk = v.wcs_user_sk --join user ""purchased items" with user "viewed items"
	AND v.click_timestamp between p.click_timestamp - (10*24*60*60) and  p.click_timestamp   --view clicks max 10 days (=10*24*60*60 seconds) before purchase

)rankedClicks
where rowNumber <= 5 --Find the last 5 products that are mostly viewed before ..
group by viewedItem
order by cnt desc -- Show the top 100 products ranked by number of views.
limit 100
;



--Cleanup
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_userClicks;
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_purchases;
drop ${hiveconf:viewOrTable} if exists  ${hiveconf:TEMP_TABLE}_viewed;
