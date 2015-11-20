#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

import sys

def npath(vals):
	vals.sort()
	last_order = -1
	last_dynamic = -1
	for i in range(len(vals)):
		if vals[i][3] == 'order':
			last_order = i
		if vals[i][3] == 'dynamic':
			last_dynamic = i 
	
	if last_dynamic > last_order:	
		print "%s\t%s\t%s" % (vals[last_order+1][4], str(vals[last_order+1][0]), str(vals[-1][0]))
	

if __name__ == "__main__":
	
	current_key = ''
	vals = []

	for line in sys.stdin:
		val1, val2, val3, val4, key = line.strip().split("\t")

		if current_key == '' :
			current_key = key
			vals.append((int(val4), val1, val2, val3, key))

		elif current_key == key:
			vals.append((int(val4), val1, val2, val3, key))

		elif current_key != key:
			npath(vals)
			vals = []
			current_key = key
			vals.append((int(val4), val1, val2, val3, key))

	npath(vals)	
	
