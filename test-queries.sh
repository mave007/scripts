#!/usr/bin/env bash

if [ -e /opt/homebrew/bin/grc ] ; then
	DIG="/opt/homebrew/bin/grc -es dig"
else
	DIG=$(which dig)
fi
SERVER=192.168.1.9

${DIG} @${SERVER} cero32.cl A                      # 1 record
${DIG} @${SERVER} cero32.cl NS                     # 3 records
${DIG} @${SERVER} cero32.cl DNSKEY +dnssec         # 4 records
${DIG} @${SERVER} cero32.cl MX                     # 5 records
${DIG} @${SERVER} cero32.cl TXT +novc +tcp         # 4 records TCP
${DIG} @${SERVER} digitalocean.com TXT             # 27 records TCP
${DIG} @${SERVER} cisco.com TXT                    # 73 records TCP
${DIG} @${SERVER} in.logtail.com A                 # 20+ A records UDP
${DIG} @${SERVER} ${RANDOM}x${RANDOM}.cero32.cl    # NXDOMAIN
${DIG} @${SERVER} cero32.cl +norec                 # REFUSED
${DIG} @${SERVER} cero32.cl ANY                    # REFUSED
${DIG} @${SERVER} cero32.cl AXFR                   # failed
${DIG} @${SERVER} ${RANDOM}.test.cero32.cl NS      # SERVFAIL
${DIG} @${SERVER} rsamd5.extended-dns-errors.com
${DIG} @${SERVER} dsa.extended-dns-errors.com
${DIG} @${SERVER} rsasha1.extended-dns-errors.com
${DIG} @${SERVER} dsa-nsec3-sha1.extended-dns-errors.com
${DIG} @${SERVER} rsasha1-nsec3-sha1.extended-dns-errors.com
${DIG} @${SERVER} rsasha256.extended-dns-errors.com
${DIG} @${SERVER} rsasha512.extended-dns-errors.com
${DIG} @${SERVER} ecdsap256sha256.extended-dns-errors.com
${DIG} @${SERVER} ecdsap384sha384.extended-dns-errors.com
${DIG} @${SERVER} ed25519.extended-dns-errors.com
${DIG} @${SERVER} ed448.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-0.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-1.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-50.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-100.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-150.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-200.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-500.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-1000.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-1500.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-2000.extended-dns-errors.com
${DIG} @${SERVER} nsec3-iter-2500.extended-dns-errors.com
${DIG} @${SERVER} test300.slow.cero32.cl
${DIG} @${SERVER} test400.slow.cero32.cl
${DIG} @${SERVER} test500.slow.cero32.cl
${DIG} @${SERVER} test600.slow.cero32.cl
${DIG} @${SERVER} test700.slow.cero32.cl
${DIG} @${SERVER} test800.slow.cero32.cl
${DIG} @${SERVER} test900.slow.cero32.cl
${DIG} @${SERVER} test1000.slow.cero32.cl
${DIG} @${SERVER} test1500.slow.cero32.cl
${DIG} @${SERVER} test2000.slow.cero32.cl
${DIG} @${SERVER} test3000.slow.cero32.cl
${DIG} @${SERVER} test4000.slow.cero32.cl
