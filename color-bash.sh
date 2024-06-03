#!/bin/bash
#
# Prints a color table of 8bg * 8fg * 4 states (regular/bold/underscore/blink)
# Original idea from https://web.archive.org/web/20120529074752/http://www.frexx.de:80/xterm-256-notes/
#

echo
echo Table for 16-color terminal escape sequences.
echo Replace ESC with \\033 in bash.
echo
echo "------------------------------------------------------------------------"
echo "| Background | Foreground colors"
echo "------------------------------------------------------------------------"

for bg in $(seq 40 47); do
	# Background color codes: 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white
	for attrib in 0 1 4 5; do
		# Attrib codes: 0=none 1=bold 4=underscore 5=blink 7=reverse 8=concealed (reverse and concealed ommited on purpose)
        echo -en "\033[0m|  ESC[${bg}m   | "
		for fg in $(seq 30 37); do
			# Text color codes: 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
			case ${attrib} in
				0) echo -en "\033[${bg}m\033[${fg}m [${fg}m  " ;;
				*) echo -en "\033[${bg}m\033[${attrib};${fg}m [${attrib};${fg}m" ;;
			esac
		done
		echo -e " \033[0m"
	done
	echo "------------------------------------------------------------------------ "
done

echo "Note that Attributes can be combined and separated by ';' example for red background, ligth dark, underscored and blinking:"
echo -e "\033[41m\033[1;5;4;30m example (ESC[41mESC[1;4;5;30m)\033[0m "
echo
echo
