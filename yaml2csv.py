#!/usr/bin/env python

import yaml
import sys
import iso8601

KEY=""
VAL=""
with open(sys.argv[1], 'r') as stream:
	docs=yaml.safe_load(stream)
	for k in iter(sorted(docs.iterkeys())):
		if "dns" in k: KEY = str(k) + ";" + KEY
		if "start-period" in k: KEY = str(k) + ";" + KEY
		if "service" in k: KEY = str(k) + ";" + KEY
	for k,v in iter(sorted(docs.iteritems())):
		if "dns" in k: VAL = str(v) + ";" + VAL
		if "start-period" in k:
			fecha=iso8601.parse_date(str(v))
			VAL = str(fecha.isoformat()) + ";" + VAL
		if "service" in k: VAL = str(v) + ";" + VAL
			
print KEY[:-1]
print VAL[:-1]
