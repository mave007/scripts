#!/usr/bin/env python2.7
#
# Giving the name of a process, writes down every 1 second information about memory and cpu for that process
#
# Based on top.py example from giampaolo
# https://github.com/giampaolo/psutil/blob/master/examples/top.py

import os
import sys
import csv
import psutil
if os.name != 'posix':
        sys.exit('platform not supported')
import time
from datetime import datetime, timedelta
from optparse import OptionParser

now = int(time.time())

def is_empty(any_structure):
    if any_structure:
        #print('Structure is not empty.')
        return False
    else:
        #print('Structure is empty.')
        return True
    
def query_yes_no(question, default="yes"):
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

    The "answer" return value is one of "yes" or "no".
    """
    valid = {"yes": True, "y": True, "ye": True,
             "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = raw_input().lower()
        if default is not None and choice == '':
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' " 
                             "(or 'y' or 'n').\n")

def bytes2human(n):
    """
    >>> bytes2human(10000)
    '9K'
    >>> bytes2human(100001221)
    '95M'
    """
    #symbols = ('K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y')
    symbols = ('K','M')
    prefix = {}
    for i, s in enumerate(symbols):
        prefix[s] = 1 << (i + 1) * 10
    for s in reversed(symbols):
        if n >= prefix[s]:
            value = int(float(n) / prefix[s])
            return '%s%s' % (value, s)
    return "%sB" % n

def poll(interval, pname, csvfile):
    # sleep some time
    time.sleep(interval)
    procs = []
    procs_status = {}
    for p in psutil.process_iter():
        if p.name() == pname :
            try:
                p.dict = p.as_dict(['nice', 'memory_info','memory_percent', 'cpu_percent', 'cpu_times', 'name', 'status', 'pid'])
                try:
                    procs_status[p.dict['status']] += 1
                except KeyError:
                    procs_status[p.dict['status']] = 1
            except psutil.NoSuchProcess:
                pass
            else:
                procs.append(p)
        elif pname == "header":
            return ([], {}, csvfile)
    # return processes sorted by PID
    processes = sorted(procs, key=lambda p: p.dict['pid'], reverse=False)
    return (processes, procs_status, csvfile)


def writecsv(procs, procs_status,csvfile):
    # If procs is not set, it must be a header
    if is_empty(procs):
        line = (
                "num",
                "proc",
                "pid",
                "ctime",
                #"nice",
                "vms",
                "rss",
                "shared",
                "text",
                "cpu%",
                "mem%"
        )
        if csvfile != "__no_output_just_verbose":
            with open(csvfile, 'a') as f:
                writer = csv.writer(f)
                writer.writerows([line])
            f.close
        else:
            print line
    # Normal data
    else:
        for p in procs:
            if p.dict['cpu_times'] is not None:
                ctime = timedelta(seconds=sum(p.dict['cpu_times']))
                ctime = "%s:%s.%s" % (ctime.seconds // 60 % 60,
                str((ctime.seconds % 60)).zfill(2),
                str(ctime.microseconds)[:2])
            else:
                ctime = ''
            if p.dict['memory_percent'] is not None:
                p.dict['memory_percent'] = round(p.dict['memory_percent'], 1)
            else:
                p.dict['memory_percent'] = ''
            if p.dict['cpu_percent'] is None:
                p.dict['cpu_percent'] = ''
            line = (
                    int(time.time()) - now,                                    # Iteration number
                    p.dict['name'] or '',                                      # Name of the process
                    p.pid,                                                     # PID
                    ctime,                                                     # CPU Time
                    # p.dict['nice'],		                               ## Nice status
                    bytes2human(getattr(p.dict['memory_info'], 'vms', 0)),     # Virtual memory
                    bytes2human(getattr(p.dict['memory_info'], 'rss', 0)),     # RSS Memory
                    bytes2human(getattr(p.dict['memory_info'], 'shared', 0)),  # Shared Memory
                    bytes2human(getattr(p.dict['memory_info'], 'text', 0)),    # Text memory
                    p.dict['cpu_percent'],		                       # CPU usage
                    p.dict['memory_percent'],	                               # Memory usage
            )
            if csvfile != "__no_output_just_verbose":
                with open(csvfile, 'ab') as f:
                    writer = csv.writer(f)
                    writer.writerows([line])
                f.close
            else:
                print line

            
#Main
def main():
    try:        
        parser = OptionParser(usage="usage: %prog [-o filename] [-v] process_name", version="%prog 1.0")
        parser.add_option("-o", "--output",
                          action="store", # optional because action defaults to "store"
                          dest="filename",
                          default="output.csv",
                          metavar="FILE",
                          help="CSV file to save the output (default: output.csv)"
                          )
        parser.add_option("-v", "--verbose",
                          action="store_true",
                          dest="verbose",
                          help="Show output instead of writing CSV")
        
        (options, args) = parser.parse_args()
        
        if len(args) != 1:
            parser.error("Wrong number of arguments")
        
        pname = args[0]
        csvfile = options.filename
        
        if options.verbose == True:
            csvfile="__no_output_just_verbose"
        else:
            if os.path.isfile(csvfile):
                if query_yes_no ("File " + csvfile + " already exists. Overwrite?"):
                    os.remove(csvfile)
            print "Writing CSV file into " + csvfile
            print " ...press CTRL + C to stop..."
            
        now = int(time.time())
        interval = 0.1
        args = poll(interval, "header", csvfile)
        while 1:
            writecsv(*args)
            interval = 1
            args = poll(interval, pname, csvfile)
    except (KeyboardInterrupt, SystemExit):
        print "\nFinished."
        pass
    

if __name__ == '__main__':
    main()
