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

def filterShoppingCharts(vals):
	#tup[0] wptype:string
	#tup[1] tstamp_str:string
	#tup[2] sessionid:string	
	
	last_order = -1
	last_dynamic = -1
	cnt = len(vals)
	for i in range(cnt):
		if vals[i][0] == 'order':
			last_order = i
		if vals[i][0] == 'dynamic':
			last_dynamic = i 
	
	#is abandonend shopping chart?
	if last_dynamic > last_order and (last_order == -1 or vals[last_dynamic][1] >= vals[last_order][1]):	
		#print sessionid ("<usersk>_<sessionCounter>") and pagecount
		print "%s\t%s" % (vals[0][2], str(cnt))
	

if __name__ == "__main__":
	#lines are expected to be grouped by sessionid and presorted by timestamp 
	line = ''
	vals = []
	
	try:
	
		# do first line outside of loop to avoid additional: if current_uid != -1 check inside the loop
		line = raw_input()
		wptype, tstamp_str ,sessionid  = line.strip().split("\t")	
		tstamp = long(tstamp_str)
		current_key = sessionid
		vals.append((wptype,tstamp, sessionid))

		for line in sys.stdin:
		
			wptype, tstamp_str ,sessionid  = line.strip().split("\t")
			tstamp = long(tstamp_str)

			if current_key == sessionid:
				vals.append((wptype,tstamp, sessionid))
				
			else:
				filterShoppingCharts(vals)
				vals = []
				vals.append((wptype,tstamp, sessionid))
				current_key = sessionid
				
		filterShoppingCharts(vals)	
		
	except:
		## should only happen if input format is not correct
		logging.basicConfig(level=logging.DEBUG, filename=strftime("/tmp/bigbench_q4_reducer2.py_%Y%m%d-%H%M%S.log"))
		logging.info("line from hive: \"" + line + "\"")
		logging.exception("Oops:") 
		sys.exit(1)	
	
