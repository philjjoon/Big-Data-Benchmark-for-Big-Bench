--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


-- Build text classifier for online review sentiment classification (Positive,
-- Negative, Neutral), using 60% of available reviews for training and the remaining
-- 40% for testing. Display classifier accuracy on testing data.

-- IMPLEMENTATION NOTICE:
-- All reviews are split as follows:
-- case (pr_review_sk % 5) in
--   1|2|3) => use for training
--   ;;
--   0|4) => use for testing
--   ;;
-- esac

-- The input format for the clustering is:
-- ID of the review, rating of the review (NEG, NEU, POS), review text
-- Fields are separated by tabs
-- Example:
-- 1\tNEU\tThis is a neutral review text\n

-- Query parameters

-- Resources
--ADD FILE ${hiveconf:QUERY_DIR}/mapper_q28.py;

--Result 1 Training table for mahout--------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE1};
CREATE TABLE ${hiveconf:TEMP_TABLE1} (
  pr_review_sk      BIGINT,
  pr_rating         STRING,
  pr_review_content STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR1}';

INSERT INTO TABLE ${hiveconf:TEMP_TABLE1}
SELECT
  pr_review_sk,
  CASE pr_review_rating
    WHEN 1 THEN 'NEG'
    WHEN 2 THEN 'NEG'
    WHEN 3 THEN 'NEU'
    WHEN 4 THEN 'POS'
    WHEN 5 THEN 'POS'
    END AS pr_rating,
  pr_review_content
FROM product_reviews
WHERE pmod(pr_review_sk, 5) IN (1,2,3)
--CLUSTER BY pr_review_sk
--no total ordering with ORDER BY required, further processed by clustering algorithm;
;

--Result 2 Testing table for mahout --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE2};
CREATE TABLE ${hiveconf:TEMP_TABLE2} (
  pr_review_sk      BIGINT,
  pr_rating         STRING,
  pr_review_content STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR2}';

INSERT INTO TABLE ${hiveconf:TEMP_TABLE2}
SELECT
  pr_review_sk,
  CASE pr_review_rating
    WHEN 1 THEN 'NEG'
    WHEN 2 THEN 'NEG'
    WHEN 3 THEN 'NEU'
    WHEN 4 THEN 'POS'
    WHEN 5 THEN 'POS'
    END AS pr_rating,
  pr_review_content
FROM product_reviews
WHERE pmod(pr_review_sk, 5) in (0,4)
--CLUSTER BY pr_review_sk
--no total ordering with ORDER BY required, further processed by clustering algorithm;
;
