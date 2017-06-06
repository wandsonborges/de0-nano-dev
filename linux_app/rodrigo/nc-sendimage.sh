#!/bin/bash
while true; do
	./a.out
	#echo "begin"
	if ! nc -w 4 192.168.1.99 4444 < /tmp/image.bin; then #2> /dev/null; then
		echo "err nc"
	#else
		#echo "image sent"
	fi
	#echo "image sent"
	#sleep 1

done

