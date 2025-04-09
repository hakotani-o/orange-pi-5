#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ $# -ne 1 ]; then
	echo "$0 linux_dir"
	exit 1
fi

linux_dir=$1
suite=oracular
rm -rf $linux_dir && mkdir $linux_dir
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 4 ]; then
	sudo mount -t tmpfs -o size=6G tmpfs $linux_dir
fi

cd $linux_dir

git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git

now=`cat linux-next/localversion-next|sed 's/-next-//'`
rm 	linux-next/localversion-next
head -5 linux-next/Makefile | sed 's# ##g' > ./tmp_var.txt
cd linux-next # 


. ../tmp_var.txt

cat arch/arm64/configs/defconfig ../../overlay/my-add.txt > .config

	EXTRAVERSION="${EXTRAVERSION}-$now"


export PACKAGE_RELEASE="$VERSION.$PATCHLEVEL.${SUBLEVEL}$EXTRAVERSION-rockchip"
export DEBIAN_PACKAGE="kernel-${PACKAGE_RELEASE%%~*}"
export MAKE="make \
			ARCH=arm64 \
			CROSS_COMPILE=aarch64-linux-gnu- \
             CC=aarch64-linux-gnu-gcc \
             HOSTCC=$ARCH_HOST_CC \
             KERNELVERSION=$PACKAGE_RELEASE \
             LOCALVERSION= \
             localver-extra= \
             PYTHON=python3"


$MAKE -j$(nproc)  all modules dtbs

export INSTALL_PATH="../${DEBIAN_PACKAGE}_arm64"
export KERNEL_BASE_PACKAGE="${DEBIAN_PACKAGE}_arm64"
rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH

$MAKE install headers_install modules_install vdso_install dtbs_install INSTALL_MOD_STRIP=1 INSTALL_HDR_PATH=$INSTALL_PATH/usr/include INSTALL_MOD_PATH=$INSTALL_PATH INSTALL_FW_PATH=$INSTALL_PATH/lib/firmware/$PACKAGE_RELEASE INSTALL_DTBS_PATH=$INSTALL_PATH/boot/dtbs/$PACKAGE_RELEASE/device-tree

mv $INSTALL_PATH/vmlinuz-$PACKAGE_RELEASE $INSTALL_PATH/boot
mv $INSTALL_PATH/config-$PACKAGE_RELEASE $INSTALL_PATH/boot
mv $INSTALL_PATH/System.map-$PACKAGE_RELEASE $INSTALL_PATH/boot

# Dummy kernel header directory
mkdir -p $INSTALL_PATH/usr/src/linux-headers-$PACKAGE_RELEASE

# DEBIAN control
cd ..
mkdir -p $KERNEL_BASE_PACKAGE/DEBIAN

cat > $KERNEL_BASE_PACKAGE/DEBIAN/control << HEREDOC
Package: $DEBIAN_PACKAGE
Source: $DEBIAN_PACKAGE
Version: $PACKAGE_RELEASE
Section: main
Priority: standard
Architecture: arm64
Depends: kmod, linux-base (>= 4.5ubuntu1~16.04.1)
Homepage: https://kernel.org/
Rules-Requires-Root: no
Maintainer: Paper <kernel@papercube>
Description: A minimal kernel package for ubuntu-server aarch64 running on opi-5-plus.
HEREDOC

# A simple postinstall script
cat > $KERNEL_BASE_PACKAGE/DEBIAN/postinst << HEREDOC
run-parts --report --exit-on-error --arg=$PACKAGE_RELEASE --arg=/boot/vmlinuz-$PACKAGE_RELEASE /etc/kernel/postinst.d
HEREDOC

# Assign proper permission for the script
chmod 755 $KERNEL_BASE_PACKAGE/DEBIAN/postinst

# Build packaage
rm -rf ../kernel && mkdir ../kernel
fakeroot dpkg-deb -z 4 -Z xz -b $KERNEL_BASE_PACKAGE ../kernel/


rm -f ../overlay/tmp_var.txt
echo "kernel install: cd kernel && sudo dpkg -i *.deb"


# Exit trap is no longer needed
trap '' EXIT
cd ..
echo "DISK usage"
df $1
if [ $mem_size -gt 4 ]; then
	sudo umount $linux_dir
	sleep 2
fi
exit 0
