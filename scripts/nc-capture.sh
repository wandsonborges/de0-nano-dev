#!/bin/bash

while true; do

	nc -l -p 4444 > /tmp/image.tmp
	mv /tmp/image.tmp /tmp/image.bin
done
