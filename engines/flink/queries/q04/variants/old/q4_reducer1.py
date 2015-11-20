#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

import sys

timeout = long(sys.argv[1])

def sessionize(vals):
	session = 1
	vals.sort()
	cur_time = vals[0][0]
	for tup in vals:
		if tup[0] - cur_time > timeout:
			session += 1
		cur_time = tup[0]
		print "%s\t%s\t%s\t%s\t%s" % (tup[1], tup[2], tup[3], tup[0], tup[1]+'_'+str(session))


if __name__ == "__main__":
	
	current_key = ''
	vals = []

	for line in sys.stdin:
		key, val1, val2, val3 = line.strip().split("\t")

		if current_key == '' :
			current_key = key
			vals.append((int(val3), key, val1, val2))

		elif current_key == key:
			vals.append((int(val3), key, val1, val2))

		elif current_key != key:
			sessionize(vals)
			vals = []
			current_key = key
			vals.append((int(val3), key, val1, val2))

	sessionize(vals)	
	
