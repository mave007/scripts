#!/usr/bin/env python

import sys

for str in sys.argv[1:]:
    for c in str:
        sys.stdout.write("%x" % ord(c))
    sys.stdout.write("\n")
    
