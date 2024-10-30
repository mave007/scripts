#!/bin/bash
#
# Desc: Check response time and hostname.bind server for a hostname in IPv4 and IPv6
# Author: Mauricio Vergara Ereche <mave@cero32.cl>
# License: GPL-3.0-or-later
#
export PATH=/usr/local/opt/coreutils/libexec/gnubin/:/usr/local/bin:/bin:/usr/bin:/usr/sbin

QRY="CH TXT hostname.bind"
FLAGS="+stats +retry=0 +timeout=1"
IPV="4 6"
PAD="                      "

function ColorRange(){
	if [[ "$1" =~ ^[0-9]+$ ]] ; then
		case "$1" in
			[1-9]) # Range 1-9 : GREEN
				colorcode="\033[1;32m"
				;;
			[0-2][0-9]) # Range 00-29 : CYAN
				colorcode="\033[0;36m"
				;;
			[3-6][0-9]) # Range 30-69 : BLUE
				colorcode="\033[1;34m"
				;;
			[7-9][0-9]) # Range 70-99 : YELLOW
				colorcode="\033[0;33m"
				;;
			1[0-4][0-9]) # Range 100-149 : BROWN
				colorcode="\033[1;33m"
				;;
			[1][5-9][0-9]) # Range 150-199 : RED
				colorcode="\033[0;31m"
				;;
			[2-9][0-9][0-9]) # Range 200-999 : RED
				colorcode="\033[0;31m"
				;;
			*)
				colorcode="\033[1;35m" # The REST PURPLE
				;;
		esac
	elif [[ "$1" =~ ^\(.*|\s?\)$ ]] ; then
		colorcode="\033[1;3;30m" # The hostname.bind ID is gray and italics
	else
		colorcode="\033[1;35m" # The REST PURPLE
	fi
	printf "%b%s%b" "${colorcode}" "${*}" "\033[0m\n"
}

function Query(){
######################
# Query() function
# param1: <domain>
# param2: <ip_version>
######################
	MIN=9999
	MAX=0
	SUM=0
	CONT=1
	if [ -z "${1}" ] || [ -z "${2}" ] ; then
		echo "Query(): error (missing parameters)"
		exit 1
	fi	
	domain="${1}"
	ipv="-${2}"
	for NS in $(dig ${FLAGS} NS ${domain} +nodnssec +short | sort); do
		ANSt="$(dig ${FLAGS} ${ipv} @${NS} ${QRY} 2>/dev/null |egrep "(Query time|^hostname.bind)" 2>/dev/null)"
		if [ $? -eq 0 ] ; then
			ANS=$(echo ${ANSt} | awk '{printf "%s",$(NF-1)}')
			NAME=$(echo ${ANSt} | cut -d '"' -f2)
			# Next printf format is:
			# <space>NameServer<padding_align>:<padding_num><answer><space><hostname>
			printf " %s %s %14s %s\n" "${NS}:" "${PAD:${#NS}}" "$(ColorRange ${ANS})" "$(ColorRange \(${NAME}\))"
			CONT=$((CONT+1))	   
		else
			printf " %s: %b%8s%b\n" ${NS} "\033[0;35m" "ERROR" "\033[0m"
		fi
		if [ $ANS -le $MIN ] ; then MIN=$ANS ; fi
		if [ $ANS -ge $MAX ] ; then MAX=$ANS ; fi
		SUM=$((SUM+ANS))
	done

	printf "MIN: $(ColorRange ${MIN}) \n"
	printf "AVG: $(ColorRange $((SUM/CONT)) )\n"
	printf "MAX: $(ColorRange ${MAX} )\n"
}

################
#  MAIN
################

if [ -z "${1}" ] ; then
	echo "ERROR: You need to give a domain as a parameter"
	echo "       ${0} cero32.cl"
	exit 1
else
	domain=${1}
fi

ColorRange "Default_routers:"
netstat -rn|grep default | grep -v 'fe80::' | awk '{ print " " $2}'

ColorRange "Default_DNS_Resolver:"
dig . | grep \;\;\ SERVER\: | cut -d ":" -f2-
echo

for ipv in ${IPV}; do
    ColorRange "IPv${ipv}:"
	Query ${domain} ${ipv}
	echo
done
