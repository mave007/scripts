#!/usr/bin/env python

import yaml
import yamlordereddictloader
import sys

KEY=""
VALUE=""
with open(sys.argv[1], 'r') as stream:
	docs=yaml.load_all(stream, Loader=yamlordereddictloader.Loader)
	for doc in docs:
		for k,v in doc.items():
			if str(v) == 'rssac002v3':
				continue
			elif str(k) == 'end-period':
				continue
			elif str(k) == 'start-period':
				KEY = KEY + str(k) + ","
				VALUE = VALUE + str(v)[0:10] + ","
			else:
				KEY = KEY + str(k) + ","
				VALUE = VALUE + str(v) + ","
			
print KEY[:-1]
print VALUE[:-1]
