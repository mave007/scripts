#!/bin/bash
#
# Util libraries to manage colors
#

export C1="\033[0;30m" # Black
export C2="\033[1;30m" # Dark Gray
export C3="\033[0;31m" # Red
export C4="\033[1;31m" # Light Red
export C5="\033[0;32m" # Green
export C6="\033[1;32m" # Light Green
export C7="\033[0;33m" # Brown
export C8="\033[1;33m" # Yellow
export C9="\033[0;34m" # Blue
export C10="\033[1;34m" # Light Blue
export C11="\033[0;35m" # Purple
export C12="\033[1;35m" # Light Purple
export C13="\033[0;36m" # Cyan
export C14="\033[1;36m" # Light Cyan
export C15="\033[0;37m" # Light Gray
export C16="\033[1;37m" # White
export P="\033[0m" # Neutral

# To test output use:
# for i in $(seq 16); do msg="C${i}" ; printf "${!msg} color code: C${i}\n" ; done ; printf "${P} neutral color"

# Individual values can be accessed with printf:
# printf "${C4}warning${P}"
