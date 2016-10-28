#!/usr/bin/env python

from optparse import OptionParser

def main():
    parser = OptionParser(usage="usage: %prog <-o filename> process", version="%prog 1.0")
    parser.add_option("-o", "--output",
    action="store", # optional because action defaults to "store"
    dest="filename",
    default="output.cvs",
    metavar="FILE",
    help="CVS file to save the output",)
    
    (options, args) = parser.parse_args()
    
    if len(args) != 1:
        parser.error("Wrong number of arguments")
        
    pname = args[0]
    print pname
    print options.filename
    
if __name__ == '__main__':
    main()
