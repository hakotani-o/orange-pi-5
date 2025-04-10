#! /bin/bash

	chroot $1 apt-get -y --no-install-recommends install ubuntu-desktop
	cd $1
	mkdir aaa
	pushd aaa

	apt-get download ubuntu-desktop
	dpkg -e ubuntu-desktop*
	cd DEBIAN
	echo '#!/bin/bash' > aa
	echo -n 'apt-get -y install ' >> aa
	grep Recommends control | sed 's/,//g' | sed 's/Recommends://' | sed 's/libreoffice-calc//' | sed 's/libreoffice-gnome//' | sed 's/libreoffice-impress//' | sed 's/libreoffice-math//' | sed 's/libreoffice-style-yaru//' | sed 's/libreoffice-writer//' | sed 's/firefox//' | sed 's/remmina//' | sed 's/rhythmbox//' | sed 's/thunderbird.//' | sed 's/transmission-gtk//' | sed 's/gnome-clocks//' | sed 's/gnome-calendar//' >> aa
	echo -n 'apt-get -y install ' >> aa
	echo -n ' gdm3 linux-firmware snapd cloud-initramfs-growroot ' >> aa
	echo -n ' oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon ' >> aa
	echo -n 'grub-efi-arm64 initramfs-tools' >> aa
	popd
	cd ..
	chroot $1 /bin/bash aaa/DEBIAN/aa
