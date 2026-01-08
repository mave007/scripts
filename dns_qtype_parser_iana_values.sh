#!/usr/bin/env bash
#
# Portable DNS QTYPE parser for Linux and macOS
# Maps numeric DNS query types to their TYPE names per IANA RFC standards

set -euo pipefail

# IANA DNS RR TYPEs mapping https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml#dns-parameters-4
# Format: qtype:TYPE
get_dns_type() {
    case "$1" in
        1) echo "A" ;; 2) echo "NS" ;; 3) echo "MD" ;; 4) echo "MF" ;;
        5) echo "CNAME" ;; 6) echo "SOA" ;; 7) echo "MB" ;; 8) echo "MG" ;;
        9) echo "MR" ;; 10) echo "NULL" ;; 11) echo "WKS" ;; 12) echo "PTR" ;;
        13) echo "HINFO" ;; 14) echo "MINFO" ;; 15) echo "MX" ;; 16) echo "TXT" ;;
        17) echo "RP" ;; 18) echo "AFSDB" ;; 19) echo "X25" ;; 20) echo "ISDN" ;;
        21) echo "RT" ;; 22) echo "NSAP" ;; 23) echo "NSAP-PTR" ;; 24) echo "SIG" ;;
        25) echo "KEY" ;; 26) echo "PX" ;; 27) echo "GPOS" ;; 28) echo "AAAA" ;;
        29) echo "LOC" ;; 30) echo "NXT" ;; 31) echo "EID" ;; 32) echo "NIMLOC" ;;
        33) echo "SRV" ;; 34) echo "ATMA" ;; 35) echo "NAPTR" ;; 36) echo "KX" ;;
        37) echo "CERT" ;; 38) echo "A6" ;; 39) echo "DNAME" ;; 40) echo "SINK" ;;
        41) echo "OPT" ;; 42) echo "APL" ;; 43) echo "DS" ;; 44) echo "SSHFP" ;;
        45) echo "IPSECKEY" ;; 46) echo "RRSIG" ;; 47) echo "NSEC" ;; 48) echo "DNSKEY" ;;
        49) echo "DHCID" ;; 50) echo "NSEC3" ;; 51) echo "NSEC3PARAM" ;; 52) echo "TLSA" ;;
        53) echo "SMIMEA" ;; 55) echo "HIP" ;; 56) echo "NINFO" ;; 57) echo "RKEY" ;;
        58) echo "TALINK" ;; 59) echo "CDS" ;; 60) echo "CDNSKEY" ;; 61) echo "OPENPGPKEY" ;;
        62) echo "CSYNC" ;; 63) echo "ZONEMD" ;; 64) echo "SVCB" ;; 65) echo "HTTPS" ;;
        66) echo "DSYNC" ;; 67) echo "HHIT" ;; 68) echo "BRID" ;; 99) echo "SPF" ;;
        100) echo "UINFO" ;; 101) echo "UID" ;; 102) echo "GID" ;; 103) echo "UNSPEC" ;;
        104) echo "NID" ;; 105) echo "L32" ;; 106) echo "L64" ;; 107) echo "LP" ;;
        108) echo "EUI48" ;; 109) echo "EUI64" ;; 128) echo "NXNAME" ;;
        249) echo "TKEY" ;; 250) echo "TSIG" ;; 251) echo "IXFR" ;; 252) echo "AXFR" ;;
        253) echo "MAILB" ;; 254) echo "MAILA" ;; 255) echo "*" ;; 256) echo "URI" ;;
        257) echo "CAA" ;; 258) echo "AVC" ;; 259) echo "DOA" ;; 260) echo "AMTRELAY" ;;
        261) echo "RESINFO" ;; 262) echo "WALLET" ;; 263) echo "CLA" ;; 264) echo "IPN" ;;
        32768) echo "TA" ;; 32769) echo "DLV" ;;
        *) echo "TYPE$1" ;;
    esac
}

usage() {
    cat >&2 <<EOF
Usage: $0 <input_file>

Parse DNS query types from numeric to TYPE format.

Input format:
  domain qtype

Output format:
  domain TYPE

Example:
  cero32.cl 1        -> cero32.cl A
  google.com 2       -> google.com NS
  facebook.com. 28   -> facebook.com. AAAA
EOF
    exit 1
}

# Input validation
[[ $# -eq 1 ]] || usage
input_file="$1"
[[ -f "$input_file" ]] || { echo "Error: File '$input_file' not found" >&2; exit 1; }

# Process file
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Parse domain and qtype with flexible whitespace handling
    read -r domain qtype <<< "$line"
    
    # Validate qtype is numeric
    if ! [[ "$qtype" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid qtype '$qtype' for domain '$domain'" >&2
        continue
    fi
    
    # Map qtype to TYPE name
    type_name=$(get_dns_type "$qtype")
    printf "%s\t%s\n" "$domain" "$type_name"
done < "$input_file"
