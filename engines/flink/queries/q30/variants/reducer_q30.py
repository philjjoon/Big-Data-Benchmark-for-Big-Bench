#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

import sys

def combinations(vals):
	vals.sort()
	last_cat_id = -1
        distinct_cat = []
	for i in vals:
		if last_cat_id != i[0]:
			last_cat_id = i[0]
			for j in distinct_cat:
				print "%s\t%s\t%s\t%s" % (i[0],i[1],j[0],j[1])
				print "%s\t%s\t%s\t%s" % (j[0],j[1],i[0],i[1])
                        distinct_cat.append(i)

if __name__ == "__main__":
	
	last_ordernum = ''
	vals = []

	for line in sys.stdin:
		ordernum, cat_id, cat = line.strip().split("\t")

		if ordernum != '\N' :
			if last_ordernum == ordernum :
				vals.append((cat_id, cat))
			else :
				combinations(vals)
				vals = []
				last_ordernum = ordernum;
				vals.append((cat_id,cat))
	combinations(vals)
