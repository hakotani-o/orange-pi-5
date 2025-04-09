#!/bin/bash

rm -f .config
cat arch/arm64/configs/defconfig ../../overlay/my-add.txt > .config



	
