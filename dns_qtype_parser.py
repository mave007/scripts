#!/usr/bin/env python3
"""
Fast DNS QTYPE parser - Maps numeric DNS query types to TYPE names.
Optimized for large files with minimal overhead.
IANA DNS RR TYPEs per RFC 6895, RFC 1035
"""

# Extract QNAME and QTYPE with tshark with:
# 
# for i in *.pcap ; do tshark -r $i -Y "udp.dstport == 53" -T fields -e dns.qry.name -e dns.qry.type >> queries_temp.txt; done
#

import sys
from typing import TextIO

# IANA DNS RR TYPEs mapping - Direct dictionary lookup O(1)
DNS_TYPES = {
    1: "A", 2: "NS", 3: "MD", 4: "MF", 5: "CNAME", 6: "SOA",
    7: "MB", 8: "MG", 9: "MR", 10: "NULL", 11: "WKS", 12: "PTR",
    13: "HINFO", 14: "MINFO", 15: "MX", 16: "TXT", 17: "RP",
    18: "AFSDB", 19: "X25", 20: "ISDN", 21: "RT", 22: "NSAP",
    23: "NSAP-PTR", 24: "SIG", 25: "KEY", 26: "PX", 27: "GPOS",
    28: "AAAA", 29: "LOC", 30: "NXT", 31: "EID", 32: "NIMLOC",
    33: "SRV", 34: "ATMA", 35: "NAPTR", 36: "KX", 37: "CERT",
    38: "A6", 39: "DNAME", 40: "SINK", 41: "OPT", 42: "APL",
    43: "DS", 44: "SSHFP", 45: "IPSECKEY", 46: "RRSIG", 47: "NSEC",
    48: "DNSKEY", 49: "DHCID", 50: "NSEC3", 51: "NSEC3PARAM",
    52: "TLSA", 53: "SMIMEA", 55: "HIP", 56: "NINFO", 57: "RKEY",
    58: "TALINK", 59: "CDS", 60: "CDNSKEY", 61: "OPENPGPKEY",
    62: "CSYNC", 63: "ZONEMD", 64: "SVCB", 65: "HTTPS", 66: "DSYNC",
    67: "HHIT", 68: "BRID", 99: "SPF", 100: "UINFO", 101: "UID",
    102: "GID", 103: "UNSPEC", 104: "NID", 105: "L32", 106: "L64",
    107: "LP", 108: "EUI48", 109: "EUI64", 128: "NXNAME",
    249: "TKEY", 250: "TSIG", 251: "IXFR", 252: "AXFR",
    253: "MAILB", 254: "MAILA", 255: "*", 256: "URI", 257: "CAA",
    258: "AVC", 259: "DOA", 260: "AMTRELAY", 261: "RESINFO",
    262: "WALLET", 263: "CLA", 264: "IPN", 32768: "TA", 32769: "DLV",
}


def process_file(input_file: TextIO) -> None:
    """Process DNS query file with optimized performance."""
    write = sys.stdout.write
    dns_get = DNS_TYPES.get
    
    for line in input_file:
        line = line.strip()
        if not line:
            continue
        
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        
        domain, qtype_str = parts
        
        try:
            qtype = int(qtype_str)
            type_name = dns_get(qtype, f"TYPE{qtype}")
            write(f"{domain}\t{type_name}\n")
        except ValueError:
            print(f"Error: Invalid qtype '{qtype_str}' for domain '{domain}'", 
                  file=sys.stderr)
            continue


def main() -> None:
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: dns_qtype_parser.py <input_file>", file=sys.stderr)
        print("\nParse DNS query types from numeric to TYPE format.", file=sys.stderr)
        print("\nInput format:  domain qtype", file=sys.stderr)
        print("Output format: domain TYPE", file=sys.stderr)
        sys.exit(1)
    
    input_path = sys.argv[1]
    
    try:
        with open(input_path, 'r', buffering=65536) as f:
            process_file(f)
    except FileNotFoundError:
        print(f"Error: File '{input_path}' not found", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()
