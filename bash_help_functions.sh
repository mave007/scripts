function valid_ipv4() {
    read addr mask < <(IFS=/; echo $1)
    if [[ ${addr} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS ; IFS='.' ; ip=($addr) ; IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    else
        stat=1
    fi
    return $stat
}

function valid_ipv6() {
    read addr mask < <(IFS=/; echo $1)
    if [[ ${addr} =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]] ; then
        stat=0
    else
        stat=1
    fi
    return $stat
}

function ipv6_expand() {
    read addr mask < <(IFS=/; echo $1)
    quads=$(grep -oE "[a-fA-F0-9]{1,4}" <<< ${addr/\/*} | wc -l)
    grep -qs ":$" <<< ${addr} && { addr="${addr}0000"; (( quads++ )); }
    grep -qs "^:" <<< ${addr} && { addr="0000${addr}"; (( quads++ )); }
    [ ${quads} -lt 8 ] && addr=${addr/::/:$(for (( i=1; i<=$(( 8 - quads )) ; i++ )); do printf "0000:"; done)}
    addr=$(for quad in $(IFS=: ; echo ${addr}); do printf "${delim}%04x" "0x${quad}"; delim=":"; done)
    [ -z $mask ] && echo ${addr} || echo ${addr}/${mask}
}

function ipv6_compact() {
    read addr mask < <(IFS=/; echo $1)
    addr=$(for quad in $(IFS=:; echo ${addr}); do printf "${delim}%x" "0x${quad}"; delim=":"; done)
    for zeros in $(grep -oE "((^|:)0)+:?" <<< $addr | sort -r | head -1); do addr=${addr/$zeros/::}; done
    [ -z $mask ] && echo ${addr} || echo ${addr}/${mask}
}

function next_ipv4() {
    read addr mask < <(IFS=/ ; echo $1)
    ip_hex=$(printf '%.2X%.2X%.2X%.2X\n' $(echo ${addr} | sed -e 's/\./ /g'))
    next_ip_hex=$(printf %.8X $(echo $(( 0x${ip_hex} + 1 )) ) )
    next_ip=$(printf '%d.%d.%d.%d\n' $(echo ${next_ip_hex} | sed -r 's/(..)/0x\1 /g' ) )
    [ -z ${mask} ] && echo ${next_ip} || echo ${next_ip}/${mask}
}

function next_ipv6() {
    read addr mask < <(IFS=/; echo $1)
    addrv6=$(ipv6_expand ${addr})
    last_hex=$(echo ${addrv6}| cut -d "/" -f1 | cut -d ":" -f8)
    next_hex=$(printf %.4X $(echo $(( 0x${last_hex} + 1 )) ) )
    next_ip="$(echo ${addrv6} | cut -d ":" -f1-7):${next_hex}"
    ipv6=$([ -z ${mask} ] && echo ${next_ip} || echo ${next_ip}/${mask})
    ipv6_compact ${ipv6}
}

function next_ip(){
	if valid_ipv4 $1 ; then
		next_ipv4 $1
	elif valid_ipv6 $1 ; then
		next_ipv6 $1
	fi
}

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
