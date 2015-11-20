--"INTEL CONFIDENTIAL"
--Copyright 2015  Intel Corporation All Rights Reserved.
--
--The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
--
--No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.


-- TASK:
-- Build a model using logistic regression: based on existing users online
-- activities and demographics, for a visitor to an online store, predict the visitors
-- likelihood to be interested in a given item category.
-- input vectors to the machine learing algorithm are:
--    user_sk             serial
--    hasCollegeEducation [0,1]
--    isMale              [0,1]
--    hasClicksInCategory [0,1]
-- TODO: updated this description once improved q5 with more features is merged


-- Resources

--Result  --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

--CREATE RESULT TABLE. Store query result externally in output_dir/qXXresult/
DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
CREATE TABLE ${hiveconf:TEMP_TABLE} (
  c_customer_sk     STRING,
  college_education STRING,
  male              STRING,
  label             STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR}';

-- the real query part

INSERT INTO TABLE ${hiveconf:TEMP_TABLE}
SELECT
  q05_tmp_Cust.c_customer_sk,
  q05_tmp_Cust.college_education,
  q05_tmp_Cust.male,
  CASE WHEN q05_tmp_Cust.clicks_in_category > 2 THEN 1 ELSE 0 END AS label
FROM (
  SELECT
    q05_tmp_cust_clicks.c_customer_sk AS c_customer_sk,
    q05_tmp_cust_clicks.college_education AS college_education,
    q05_tmp_cust_clicks.male AS male,
    SUM(
      CASE WHEN q05_tmp_cust_clicks.i_category = ${hiveconf:q05_i_category}
      THEN 1
      ELSE 0 END
    ) AS clicks_in_category
  FROM (
    SELECT
      ct.c_customer_sk AS c_customer_sk,
      CASE WHEN cdt.cd_education_status IN (${hiveconf:q05_cd_education_status_IN})
        THEN 1 ELSE 0 END AS college_education,
      CASE WHEN cdt.cd_gender = ${hiveconf:q05_cd_gender}
        THEN 1 ELSE 0 END AS male,
      it.i_category AS i_category
    FROM customer ct
    INNER JOIN customer_demographics cdt ON ct.c_current_cdemo_sk = cdt.cd_demo_sk
    INNER JOIN web_clickstreams wcst ON (wcst.wcs_user_sk = ct.c_customer_sk
      AND wcst.wcs_user_sk IS NOT NULL)
    INNER JOIN item it ON wcst.wcs_item_sk = it.i_item_sk
  ) q05_tmp_cust_clicks
  GROUP BY
    q05_tmp_cust_clicks.c_customer_sk,
    q05_tmp_cust_clicks.college_education,
    q05_tmp_cust_clicks.male
) q05_tmp_Cust
;
