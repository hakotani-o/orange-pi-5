#! /bin/bash

	cd /aaa
	apt-get -y --no-install-recommends install ubuntu-desktop

	apt-get download ubuntu-desktop && chown _apt ubuntu-desktop*
	dpkg -e ubuntu-desktop*
	cd DEBIAN
	echo '#!/bin/bash' > aa
	echo -n 'apt-get -y install ' >> aa
	grep Recommends control | sed 's/,//g' | sed 's/Recommends://' | sed 's/libreoffice-calc//' | sed 's/libreoffice-gnome//' | sed 's/libreoffice-impress//' | sed 's/libreoffice-math//' | sed 's/libreoffice-style-yaru//' | sed 's/libreoffice-writer//' | sed 's/firefox//' | sed 's/remmina//' | sed 's/rhythmbox//' | sed 's/thunderbird.//' | sed 's/transmission-gtk//' | sed 's/gnome-clocks//' | sed 's/gnome-calendar//' | sed 's/| dracut/\n apt-get -y install /' >> aa
	echo -n 'apt-get -y install ' >> aa
	echo -n ' gdm3 linux-firmware snapd cloud-initramfs-growroot ' >> aa
	echo -n ' oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon ' >> aa
	echo -n 'grub-efi-arm64 initramfs-tools' >> aa
	cd /
	/bin/bash /aaa/DEBIAN/aa
