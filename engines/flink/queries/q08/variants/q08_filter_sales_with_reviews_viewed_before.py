#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

import sys
import logging
import traceback
import os
import time
from time import strftime

category=sys.argv[1] 
days_before_sale = long(sys.argv[2])
	

if __name__ == "__main__":
	line = ''
	try:
		current_key = ''
		last_review_date=-1
		#expects input to be partitioned by uid and sorted by date_sk (and timestamp) ascending

		
		for line in sys.stdin:
			uid, date_sk_str, sales_sk, wpt = line.strip().split("\t")

			#reset on partition change
			if current_key != uid :
				current_key = uid
				last_review_date = -1
				
			date_sk = int(date_sk_str)
				
			#found review before purchase, save last review date
			if wpt == category:
				last_review_date = date_sk
				continue
			
			if last_review_date > 0  and sales_sk != '\N' and (date_sk - last_review_date) <= days_before_sale :
				print sales_sk
				last_review_date = -1

	except:
	 ## should only happen if input format is not correct, like 4 instead of 5 tab separated values
		logging.basicConfig(level=logging.DEBUG, filename=strftime("/tmp/bigbench_q8_reducer_%Y%m%d-%H%M%S.log"))
		logging.info('category: ' +category )
		logging.info("line from hive: \"" + line + "\"")
		logging.exception("Oops:")
		raise
		sys.exit(1)
