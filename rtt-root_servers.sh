#!/bin/bash
export PATH=/usr/local/opt/coreutils/libexec/gnubin/:/usr/local/bin:/bin:/usr/bin

QRY=". SOA"
FLAGS="+noall +stats"
IPV="4 6"

function Query(){
MIN=9999
MAX=0
SUM=0
CONT=1
ipv="-${1}"
for roots in {a..m}; do
	ROOT="${roots}.root-servers.net"
	ANSt=$(dig ${FLAGS} ${ipv} @${ROOT} ${QRY} 2>/dev/null)
	if [ $? -eq 0 ] ; then
		ANS=$(echo ${ANSt} | grep "Query time:" | cut -d " " -f 4)
		printf " ${ROOT} : %3d\n" ${ANS}
		CONT=$((CONT+1))	   
	else
		echo -e " ${ROOT} : ERROR"
	fi
	if [ $ANS -le $MIN ] ; then MIN=$ANS ; fi
	if [ $ANS -ge $MAX ] ; then MAX=$ANS ; fi
	SUM=$((SUM+ANS))
done

echo "MIN: ${MIN}"
echo "AVG: $((SUM/CONT))"
echo "MAX: ${MAX}"
}

for ipv in ${IPV}; do
    echo "IPver: ${ipv}"
	Query ${ipv}
	echo
done
