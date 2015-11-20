--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


-- For a given product, measure the effect of competitor's prices on
-- products' in-store and online sales. (Compute the cross-price elasticity of demand
-- for a given product.

-- IMPLEMENTATION NOTICE:

-- Step1 :
-- Calculating the Percentage Change in Quantity Demanded of Good X : [QDemand(NEW) - QDemand(OLD)] / QDemand(OLD)

-- Step 2:
-- Calculating the Percentage Change in Price of Good Y: [Price(NEW) - Price(OLD)] / Price(OLD)

-- Step 3 final:
-- Cross-Price Elasticity of Demand (CPEoD) is given by: CPEoD = (% Change in Quantity Demand for Good X)/(% Change in Price for Good Y))

-- Resources


-- compute the price change % for the competitor times
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};
CREATE VIEW ${hiveconf:TEMP_TABLE1} AS
SELECT
  i_item_sk,
  (imp_competitor_price - i_current_price)/i_current_price AS price_change,
  imp_start_date,
  (imp_end_date - imp_start_date) AS no_days_comp_price
FROM item i
JOIN item_marketprices imp ON i.i_item_sk = imp.imp_item_sk
WHERE i.i_item_sk IN (${hiveconf:q24_i_item_sk_IN})
AND imp.imp_competitor_price < i.i_current_price
ORDER BY i_item_sk, imp_start_date
;


--websales items sold quantity before and after competitor price change
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE2};
CREATE VIEW ${hiveconf:TEMP_TABLE2} AS
SELECT
  ws_item_sk,
  SUM(
    CASE WHEN ws_sold_date_sk >= c.imp_start_date
    AND ws_sold_date_sk < c.imp_start_date + c.no_days_comp_price
    THEN ws_quantity
    ELSE 0 END
  ) AS current_ws_quant,
  SUM(
    CASE WHEN ws_sold_date_sk >= c.imp_start_date - c.no_days_comp_price
    AND ws_sold_date_sk < c.imp_start_date
    THEN ws_quantity
    ELSE 0 END
  ) AS prev_ws_quant
FROM web_sales ws
JOIN ${hiveconf:TEMP_TABLE1} c ON ws.ws_item_sk = c.i_item_sk
GROUP BY ws_item_sk
;


--storesales items sold quantity before and after competitor price change
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE3};
CREATE VIEW ${hiveconf:TEMP_TABLE3} AS
SELECT
  ss_item_sk,
  SUM(
    CASE WHEN ss_sold_date_sk >= c.imp_start_date
    AND ss_sold_date_sk < c.imp_start_date + c.no_days_comp_price
    THEN ss_quantity
    ELSE 0 END
  ) AS current_ss_quant,
  SUM(
    CASE WHEN ss_sold_date_sk >= c.imp_start_date - c.no_days_comp_price
    AND ss_sold_date_sk < c.imp_start_date
    THEN ss_quantity
    ELSE 0 END
  ) AS prev_ss_quant
FROM store_sales ss
JOIN ${hiveconf:TEMP_TABLE1} c ON c.i_item_sk = ss.ss_item_sk
GROUP BY ss_item_sk
;


--Result  --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  i_item_sk              BIGINT,
  cross_price_elasticity decimal(15,7)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR}';

-- Begin: the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT
  i_item_sk,
  (current_ss_quant + current_ws_quant - prev_ss_quant - prev_ws_quant) / ((prev_ss_quant + prev_ws_quant) * price_change) AS cross_price_elasticity
FROM ${hiveconf:TEMP_TABLE1} c
JOIN ${hiveconf:TEMP_TABLE2} ws ON c.i_item_sk = ws.ws_item_sk
JOIN ${hiveconf:TEMP_TABLE3} ss ON c.i_item_sk = ss.ss_item_sk
-- no ORDER BY required, result is a single row for the selected item
;


-- clean up -----------------------------------
DROP VIEW ${hiveconf:TEMP_TABLE1};
DROP VIEW ${hiveconf:TEMP_TABLE2};
DROP VIEW ${hiveconf:TEMP_TABLE3};
