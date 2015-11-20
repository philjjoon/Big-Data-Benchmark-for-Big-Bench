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

timeout = long(sys.argv[1])

def sessionize(vals):
	#tup[0] uid:long
	#tup[1] wptype:string
	#tup[2] tstamp:long
	perUser_sessionID_counter = 1
	cur_time = vals[0][2]
	for tup in vals:
		if tup[2] - cur_time > timeout:
			perUser_sessionID_counter += 1
		cur_time = tup[2]
		print "%s\t%s\t%s" % (tup[1], tup[2], tup[0]+"_"+str(perUser_sessionID_counter) )

if __name__ == "__main__":
	line = ''
	vals = []
	
	try:
		# do first line outside of loop to avoid additional: if current_uid != -1 check inside the loop
		line = raw_input()
		uid_str,  tstamp_str, wptype  = line.strip().split("\t")
		tstamp = long(tstamp_str)
		current_uid	= uid_str	
		vals.append((uid_str,  wptype, tstamp))
		
		for line in sys.stdin:
		
			uid_str, tstamp_str, wptype = line.strip().split("\t")
			tstamp = long(tstamp_str)

			if current_uid == uid_str:
				vals.append((uid_str,  wptype, tstamp))
				
			else:
				sessionize(vals)
				current_uid = uid_str
				sessionize(vals)
				vals = []
				vals.append((uid_str,  wptype, tstamp))
		

		sessionize(vals)	
		
	except:
		## should only happen if input format is not correct, like 4 instead of 5 tab separated values
		logging.basicConfig(level=logging.DEBUG, filename=strftime("/tmp/bigbench_q4_reducer1.py_%Y%m%d-%H%M%S.log"))
		logging.info("sys.argv[1] timeout: " +str(timeout) + " line from hive: \"" + line + "\"")
		logging.exception("Oops:") 
		sys.exit(1)		
