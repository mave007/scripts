#!/bin/bash
#
# Desc: Check response time and hostname.bind server for each of the root-servers in IPv4 and IPv6
# Author: Mauricio Vergara Ereche <mave@cero32.cl>
# License: GPL-3.0-or-later
#
export PATH=/usr/local/opt/coreutils/libexec/gnubin/:/usr/local/bin:/bin:/usr/bin:/usr/sbin

QRY="CH TXT hostname.bind"
FLAGS="+stats"
IPV="4 6"

function ColorRange(){
if [[ $1 =~ ^-?[0-9]+$ ]] ; then 
	case $1 in
		[1-9]) # Range 1-9 : GREEN
			colorcode="\033[1;32m"
			;;
		[0-2][0-9]) # Range 00-29 : CYAN
			colorcode="\033[0;36m"
			;;
		[3-6][0-9]) # Range 30-69 : BLUE
			colorcode="\033[1;34m"
			;;
		[7-9][0-9]) # Range 80-99 : YELLOW
			colorcode="\033[0;33m"
			;;
		1[0-4][0-9]) # Range 100-149 : BROWN
			colorcode="\033[1;33m"
			;;
		[1-9][5-9][0-9]) # Range 150-999 : RED
			colorcode="\033[0;31m"
			;;
		*)
			colorcode="\033[1;35m " # The REST PURPLE
	esac
	printf "%b%3d%b" ${colorcode} $1 "\033[0m"
else
	colorcode="\033[1;35m " # The REST PURPLE
	printf "%b%s%b" ${colorcode} ${*} "\033[0m\n"
fi
}

function Query(){
MIN=9999
MAX=0
SUM=0
CONT=1
ipv="-${1}"
for roots in {A..M}; do
	ROOT="${roots}.ROOT-SERVERS.NET."
	ANSt="$(dig ${FLAGS} ${ipv} @${ROOT} ${QRY} 2>/dev/null |egrep "(Query time|^hostname.bind)" 2>/dev/null)"
	if [ $? -eq 0 ] ; then
		ANS=$(echo ${ANSt} | awk '{printf "%s",$(NF-1)}')
		NAME=$(echo ${ANSt} | cut -d '"' -f2)
		printf " ${ROOT}: $(ColorRange ${ANS}) (${NAME})\n"
		CONT=$((CONT+1))	   
	else
		printf " %s: %bERROR %b\n" ${ROOT} "\033[0;35m" "\033[0m"
	fi
	if [ $ANS -le $MIN ] ; then MIN=$ANS ; fi
	if [ $ANS -ge $MAX ] ; then MAX=$ANS ; fi
	SUM=$((SUM+ANS))
done

printf "MIN: $(ColorRange ${MIN}) \n"
printf "AVG: $(ColorRange $((SUM/CONT)) )\n"
printf "MAX: $(ColorRange ${MAX} )\n"
}

ColorRange "Default_routers:"
netstat -rn|grep default|grep -v "fe80::"|awk '{ print $2}'
echo

ColorRange "Default_DNS_Resolver:"
dig . | grep \;\;\ SERVER\: | cut -d ":" -f2-
echo

for ipv in ${IPV}; do
    ColorRange "IPv${ipv}:"
	Query ${ipv}
	echo
done

