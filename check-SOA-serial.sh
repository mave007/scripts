#!/bin/bash
#
# Desc: Check SOA serial records for every NS in a given domain
# Author: Mauricio Vergara Ereche <mave@cero32.cl>
# License: GPL-3.0-or-later
#
export PATH=/usr/local/opt/coreutils/libexec/gnubin/:/usr/local/bin:/bin:/usr/bin:/usr/sbin

QRY="SOA"
FLAGS="+stats +retry=0 +timeout=1 +nocrypto +nomulti +noall +ans +nodnssec"

#####################
# Print func Helper
# params:
#  $1:  serial
#  $2:  name_server
#  $3:  serialdiff (1,0)
#####################
function Colorize(){
	serial=${1}
	ns=${2}
	serialdiff=${3}
	# Check if we are doing a title or a serial comp
	if [[ $serial =~ ^-?[0-9]+$ ]] ; then 
		if [[ ${serialdiff} -eq 1 ]] ; then
			colorcode="\033[1;32m " # Green
			printf "%b%3d%b" ${colorcode} ${serial} "\033[0m ${ns}"
		else
			colorcode="\033[1;31m " # Red
			printf "%b%s%b" ${colorcode} ${serial} "\033[0m ${ns}"
		fi
	else	
		colorcode="\033[1;35m " # The REST PURPLE
		printf "%b%s%b" ${colorcode} ${*} "\033[0m\n"
	fi
}

##########################
# QuerySerial func Helper
# params:
#  $1: ipversion		(4, 6)
#  $2: domain			(fqdn)
#  $3: NameServer		(fqdn)
#  $4: Serial to Compare (long int)
##########################
function QuerySerial(){
	ipv="${1}"    # The "-" is for the flag
	domain="${2}"
	ns="${3}"
	comp="${4}"
	declare -a soa_resp=($(dig @${ns} ${FLAGS} ${ipv} ${domain} ${QRY} ))
	if [ $? -eq 0 ] ; then
		serial=${soa_resp[6]}
		unset soa_resp
	else
		echo "Error getting SOA serial for domain: ${domain} with NS: ${ns}"
		exit 2
	fi
	ns_name=$(dig @${ns} CH TXT hostname.bind +short ${FLAGS} ${ipv})
	if [ $? -eq 0 ] ; then
		if [ ${serial} -eq ${comp} ] ; then
			serialdiff=1
		else 
			serialdiff=0	
		fi
		printf " ${ns}: $(Colorize ${serial} ${ns_name} ${serialdiff}) \n"
	else
		printf " %s: %bERROR %b\n" ${ROOT} "\033[0;35m" "\033[0m"
	fi
}


#######################
# MAIN
#######################
# Printing default info
Colorize "Default_routers:"
netstat -rn|grep default|grep -v "fe80::"|awk '{ print $2}'|uniq
echo
Colorize "Default_DNS_Resolver:"
dig . | grep \;\;\ SERVER\: | cut -d ":" -f2-
echo

# First Query to get SOA serial to compare
domain="."
declare -a soa_orig=($(dig @a.root-servers.net. ${FLAGS} -4 ${domain} ${QRY} ))
serial_orig=${soa_orig[6]}

# Now we compare that against every server
for ipv in "-4" "-6"; do
    Colorize "IPv${ipv}:"
	for roots in {A..M}; do
		ns="${roots}.ROOT-SERVERS.NET."
		QuerySerial ${ipv} ${domain} ${ns} ${serial_orig}
	done
	echo
done

