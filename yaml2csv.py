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
			KEY = KEY + str(k) + ","
			VALUE = VALUE + str(v) + ","

print KEY[:-1]
print VALUE[:-1]
