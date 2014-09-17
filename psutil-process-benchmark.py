#!/usr/bin/env python2.7

import os
import sys
import csv
import psutil
if os.name != 'posix':
        sys.exit('platform not supported')

import time
from datetime import datetime, timedelta

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

def poll(interval, pname):
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
    
    # return processes sorted by PID
    processes = sorted(procs, key=lambda p: p.dict['pid'], reverse=False)
    return (processes, procs_status)


def writecsv(procs, procs_status):
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
        int(time.time()),
        p.dict['name'] or '',
        p.pid,
        ctime,
        p.dict['nice'],
        bytes2human(getattr(p.dict['memory_info'], 'vms', 0)),
        bytes2human(getattr(p.dict['memory_info'], 'rss', 0)),
        bytes2human(getattr(p.dict['memory_info'], 'shared', 0)),
        bytes2human(getattr(p.dict['memory_info'], 'text', 0)),
        p.dict['cpu_percent'],
        p.dict['memory_percent'],
        
        )
        #try:
        print(line)
        #except

#Main
try:
    interval = 0
    pname = sys.argv[1]
    while 1:
        args = poll(interval, pname)
        writecsv(*args)
        interval = 1
except (KeyboardInterrupt, SystemExit):
    pass
