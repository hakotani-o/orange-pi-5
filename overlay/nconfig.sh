#!/bin/bash

rm -f .config
cat arch/arm64/configs/defconfig ../../overlay/my-add.txt > .config

{
	sleep 10
	echo '6'
	sleep 3
	echo "\n"
	sleep 3
	echo "\n"
	echo '9'
	echo "\n"
} | make nconfig

	
