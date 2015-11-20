--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

-- based on tpc-ds q39
-- This query contains multiple, related iterations:

-- Iteration 1: Calculate the coefficient of variation and mean of every item
-- and warehouse of the given and the consecutive month

-- Iteration 2: Find items that had a coefficient of variation of 1.5 or larger
-- in the given and the consecutive month


DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
CREATE TABLE ${hiveconf:TEMP_TABLE} AS
SELECT
  w_warehouse_name,
  w_warehouse_sk,
  i_item_sk,
  d_moy,
  stdev,
  mean,
  cast( (CASE mean WHEN 0.0 THEN NULL ELSE stdev/mean END) as decimal(15,5)) cov
FROM (
  SELECT
    w_warehouse_name,
    w_warehouse_sk,
    i_item_sk,
    d_moy,
    cast(stddev_samp(inv_quantity_on_hand) as decimal(15,5)) stdev,
    cast(avg(inv_quantity_on_hand) as decimal(15,5)) mean
  FROM inventory inv
  JOIN date_dim d ON (inv.inv_date_sk = d.d_date_sk
  AND d.d_year = ${hiveconf:q23_year} )
  JOIN item i ON inv.inv_item_sk = i.i_item_sk
  JOIN warehouse w ON inv.inv_warehouse_sk = w.w_warehouse_sk
  GROUP BY
    w_warehouse_name,
    w_warehouse_sk,
    i_item_sk,
    d_moy
) q23_tmp_inv_part
WHERE stdev > mean AND mean > 0 --if stdev > mean then stdev/mean is greater 1.0
;

--- RESULT PART 1--------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

-- This query requires parallel orderby for fast and deterministic global ordering of final result
set hive.optimize.sampling.orderby=${hiveconf:bigbench.hive.optimize.sampling.orderby};
set hive.optimize.sampling.orderby.number=${hiveconf:bigbench.hive.optimize.sampling.orderby.number};
set hive.optimize.sampling.orderby.percent=${hiveconf:bigbench.hive.optimize.sampling.orderby.percent};
--debug print
set hive.optimize.sampling.orderby;
set hive.optimize.sampling.orderby.number;
set hive.optimize.sampling.orderby.percent;

--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE1};
CREATE TABLE ${hiveconf:RESULT_TABLE1} (
  inv1_w_warehouse_sk BIGINT,
  inv1_i_item_sk      BIGINT,
  inv1_d_moy          INT,
  inv1_mean           decimal(15,5),
  inv1_cov            decimal(15,5),
  inv2_w_warehouse_sk BIGINT,
  inv2_i_item_sk      BIGINT,
  inv2_d_moy          INT,
  inv2_mean           decimal(15,5),
  inv2_cov            decimal(15,5)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR1}';

-- Begin: the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE1}
SELECT
  inv1.w_warehouse_sk AS inv1_w_warehouse_sk,
  inv1.i_item_sk AS inv1_i_item_sk,
  inv1.d_moy AS inv1_d_moy,
  inv1.mean AS inv1_mean,
  inv1.cov AS inv1_cov,
  inv2.w_warehouse_sk AS inv2_w_warehouse_sk,
  inv2.i_item_sk AS inv2_i_item_sk,
  inv2.d_moy AS inv2_d_moy,
  inv2.mean AS inv2_mean,
  inv2.cov AS inv2_cov
FROM ${hiveconf:TEMP_TABLE} inv1
JOIN ${hiveconf:TEMP_TABLE} inv2 ON (
  inv1.i_item_sk = inv2.i_item_sk
  AND inv1.w_warehouse_sk = inv2.w_warehouse_sk
  AND inv1.d_moy = ${hiveconf:q23_month}
  AND inv2.d_moy = ${hiveconf:q23_month} + 1
)
ORDER BY
  inv1_w_warehouse_sk,
  inv1_i_item_sk,
  inv1_d_moy,
  inv1_mean,
  inv1_cov,
  inv2_d_moy,
  inv2_mean,
  inv2_cov
;


--- RESULT PART 2--------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

-- This query requires parallel orderby for fast and deterministic global ordering of final result
set hive.optimize.sampling.orderby=${hiveconf:bigbench.hive.optimize.sampling.orderby};
set hive.optimize.sampling.orderby.number=${hiveconf:bigbench.hive.optimize.sampling.orderby.number};
set hive.optimize.sampling.orderby.percent=${hiveconf:bigbench.hive.optimize.sampling.orderby.percent};
--debug print
set hive.optimize.sampling.orderby;
set hive.optimize.sampling.orderby.number;
set hive.optimize.sampling.orderby.percent;

--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE2};
CREATE TABLE ${hiveconf:RESULT_TABLE2} (
  inv1_w_warehouse_sk BIGINT,
  inv1_i_item_sk      BIGINT,
  inv1_d_moy          INT,
  inv1_mean           decimal(15,5),
  inv1_cov            decimal(15,5),
  inv2_w_warehouse_sk BIGINT,
  inv2_i_item_sk      BIGINT,
  inv2_d_moy          INT,
  inv2_mean           decimal(15,5),
  inv2_cov            decimal(15,5)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table} LOCATION '${hiveconf:RESULT_DIR2}';

-- Begin: the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE2}
SELECT
  inv1.w_warehouse_sk AS inv1_w_warehouse_sk,
  inv1.i_item_sk AS inv1_i_item_sk,
  inv1.d_moy AS inv1_d_moy,
  inv1.mean AS inv1_mean,
  inv1.cov AS inv1_cov,
  inv2.w_warehouse_sk AS inv2_w_warehouse_sk,
  inv2.i_item_sk AS inv2_i_item_sk,
  inv2.d_moy AS inv2_d_moy,
  inv2.mean AS inv2_mean,
  inv2.cov AS inv2_cov
FROM ${hiveconf:TEMP_TABLE} inv1
JOIN ${hiveconf:TEMP_TABLE} inv2 ON (
  inv1.i_item_sk = inv2.i_item_sk
  AND inv1.w_warehouse_sk = inv2.w_warehouse_sk
  AND inv1.d_moy = ${hiveconf:q23_month}
  AND inv2.d_moy = ${hiveconf:q23_month} + 1
  AND inv1.cov > ${hiveconf:q23_coefficient}
)
ORDER BY
  inv1_w_warehouse_sk,
  inv1_i_item_sk,
  inv1_d_moy,
  inv1_mean,
  inv1_cov,
  inv2_d_moy,
  inv2_mean,
  inv2_cov
;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
