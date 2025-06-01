#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

kernel=`ls ./next-*.deb|wc -l`
if [ $kernel -ne 1 ]; then
	echo "Build kernel first"
	exit 1
fi

setup_mountpoint() {
    local mountpoint="$1"

    if [ ! -c /dev/mem ]; then
        mknod -m 660 /dev/mem c 1 1
        chown root:kmem /dev/mem
    fi

    mount dev-live -t devtmpfs "$mountpoint/dev"
    mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
    mount proc-live -t proc "$mountpoint/proc"
    mount sysfs-live -t sysfs "$mountpoint/sys"
    mount securityfs -t securityfs "$mountpoint/sys/kernel/security"
    # Provide more up to date apparmor features, matching target kernel
    # cgroup2 mount for LP: 1944004
    mount -t cgroup2 none "$mountpoint/sys/fs/cgroup"
    mount -t tmpfs none "$mountpoint/tmp"
    mount -t tmpfs none "$mountpoint/var/lib/apt/lists"
    mount -t tmpfs none "$mountpoint/var/cache/apt"
}
teardown_mountpoint() {
    # Reverse the operations from setup_mountpoint
    local mountpoint
    mountpoint=$(realpath "$1")

    # ensure we have exactly one trailing slash, and escape all slashes for awk
    mountpoint_match=$(echo "$mountpoint" | sed -e's,/$,,; s,/,\\/,g;')'\/'
    # sort -r ensures that deeper mountpoints are unmounted first
    awk </proc/self/mounts "\$2 ~ /$mountpoint_match/ { print \$2 }" | LC_ALL=C sort -r | while IFS= read -r submount; do
        mount --make-private "$submount"
        umount "$submount"
    done
}

#Bootstrap the system
rm -rf $1
mkdir $1
chroot_dir=$1
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 15 ]; then
	mount -t tmpfs -o size=10G tmpfs $chroot_dir
fi

suite=plucky
Uri="http://ports.ubuntu.com/ubuntu-ports"
	debootstrap --arch=arm64 $suite arm64 $Uri

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export  LC_ALL=C
export  LC_CTYPE=C
export  LANGUAGE=C
export  LANG=C 
chroot $1 apt-get clean

#Setup DNS
echo "127.0.0.1 localhost" > $1/etc/hosts
echo "nameserver 8.8.8.8" > $1/etc/resolv.conf
echo "nameserver 8.8.4.4" >> $1/etc/resolv.conf

#sources.list setup
rm $1/etc/hostname
echo "ubuntu-desktop" > $1/etc/hostname
{
echo "Types: deb"
echo "URIs: $Uri"
echo "Suites: $suite $suite-updates $suite-backports"
echo "Components: main universe restricted multiverse"
echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
echo ""
echo "## Ubuntu security updates. Aside from URIs and Suites,"
echo "## this should mirror your choices in the previous section."
echo "Types: deb"
echo "URIs: $Uri"
echo "Suites: $suite-security"
echo "Components: main universe restricted multiverse"
echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
} > $1/etc/apt/sources.list.d/ubuntu.sources
rm -f $1/etc/apt/sources.list

#setup custom packages
setup_mountpoint $chroot_dir

chroot $1 apt-get update
chroot $1 apt-get -y upgrade
chroot $1 apt-get -y dist-upgrade
chroot $1 apt-get -y install apt-utils software-properties-common

mkdir $1/aaa
cp ./pkg-name.sh $1/aaa && chmod +x $1/aaa/pkg-name.sh
chroot $1 /aaa/pkg-name.sh

chroot $1 apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison sudo libgnutls28-dev

# mesa
chroot $1 apt-get -y install flex bison python3-mako libwayland-egl-backend-dev libxcb-dri3-dev libxcb-dri2-0-dev libxcb-glx0-dev libx11-xcb-dev \
libxcb-present-dev libxcb-sync-dev libxxf86vm-dev libxshmfence-dev libxrandr-dev libwayland-dev libxdamage-dev libxext-dev libxfixes-dev \
x11proto-dri2-dev  x11proto-present-dev x11proto-gl-dev x11proto-xf86vidmode-dev libexpat1-dev libudev-dev gettext mesa-utils xutils-dev \
libpthread-stubs0-dev ninja-build bc flex bison cmake git valgrind python3-pip pkg-config zlib1g-dev wayland-protocols libxcb-shm0-dev meson \
llvm-20-dev libclang-cpp20-dev libclc-20-dev libllvmspirvlib-20-dev spirv-tools libopencl-clang-20-dev clang-20 libclang-20-dev llvm-spirv-20 \
libclang-common-20-dev
chroot $1 apt-get -y purge cloud-init flash-kernel fwupd

chroot $1 apt-get update
chroot $1 apt-get -y upgrade

sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' $1/etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' $1/etc/adduser.conf

    # Create the oem user account only if it doesn't already exist
    if ! id "oem" &>/dev/null; then
        chroot $1 /usr/sbin/useradd -d /home/oem -G adm,sudo,video -m -N -u 29999 oem
        chroot $1 /usr/sbin/oem-config-prepare --quiet
        chroot $1 touch "/var/lib/oem-config/run" 
    fi

# kernel
mkdir $1/kkk && cp next-*.deb $1/kkk
chroot $1 /bin/bash -c "cd kkk && dpkg -i *.deb"

# mesa
mkdir $1/bbb
chroot $1 /bin/bash -c "cd bbb && git clone --depth 1 https://gitlab.freedesktop.org/mesa/drm && cd drm/ && mkdir build && cd build/ && meson && ninja install"
chroot $1 /bin/bash -c "cd bbb && git clone --depth 1 -b staging/25.1 https://gitlab.freedesktop.org/mesa/mesa.git && cd mesa && mkdir build && cd build && meson -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dlibunwind=false -Dprefix=/opt/panfrost && ninja install && echo /opt/panfrost/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panfrost.conf && echo 'VK_DRIVER_FILES="/opt/panfrost/share/vulkan/icd.d/panfrost_icd.aarch64.json"' >> /etc/environment"

echo "DISK usage"
df $1  
rm -rf $1/aaa $1/bbb $1/kkk
kernel_version="`ls -1 $1/boot/vmlinu?-*|sed 's#-# #' | awk '{ print $2 }'`"
echo "kernel_version=$kernel_version" > ./kernel_version
# install U-Boot
chroot $1 apt-get -y install u-boot-tools u-boot-menu

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > $1/etc/kernel/cmdline
echo -n " quiet splash plymouth.ignore-serial-consoles" >> $1/etc/kernel/cmdline

# Override u-boot-menu config
mkdir -p $1/usr/share/u-boot-menu/conf.d
cat << 'EOF' > $1/usr/share/u-boot-menu/conf.d/ubuntu.conf
U_BOOT_UPDATE="true"
U_BOOT_PROMPT="1"
U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"
U_BOOT_TIMEOUT="20"
EOF

rm -f $1/var/lib/dbus/machine-id
true > $1/etc/machine-id
touch $1/var/log/syslog
chown syslog:adm $1/var/log/syslog
chroot $1 ssh-keygen -A

# debug
echo "linux-version"
chroot $1 linux-version list

chroot $1 apt-get  clean
chroot $1 apt-get -y autoremove


teardown_mountpoint $chroot_dir
rm -f wget-log*
rm -f $1/boot/*.old
#tar the rootfs
rootfs="./ubuntu-mainline.rootfs.tar"
echo "rootfs=$rootfs" > ./rootfs
cd $1
rm -rf ../$rootfs
sync
tar -cf ../$rootfs --xattrs ./*
cd ..
# Exit trap is no longer needed
trap '' EXIT
if [ $mem_size -gt 15 ]; then
	umount $1
	sleep 2
fi
exit 0
