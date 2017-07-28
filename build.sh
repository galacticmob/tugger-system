#!/bin/bash
# Build script for the tugger-system

# This script will:
# - update the os-release and issue files with the current info from git
# - build the system container (make sure you built toolchain first)
# - build the iso image

# check we are running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# get the git version info and create a new os-release file
commit="`git log --pretty=format:'%h' -n 1`"
CREATED_OSRELEASE=0
if [ ! -f rootfs/etc/os-release ]; then
	echo "Creating /etc/os-release for tugger ${commit}"
	CREATED_OSRELEASE=1
	echo "NAME=tugger" > rootfs/etc/os-release
	echo "VERSION=git-${commit}" >> rootfs/etc/os-release
	echo "ID=tugger" >> rootfs/etc/os-release
	echo "VERSION_ID=git-${commit}" >> rootfs/etc/os-release
	echo "PRETTY_NAME=\"tugger OS git-${commit}\"" >> rootfs/etc/os-release
fi

# create /etc/issue also
CREATED_ISSUE=0
if [ ! -f rootfs/etc/issue ]; then
	echo "Creating /etc/issue for tugger ${commit}"
	CREATED_ISSUE=1
	echo "tugger OS git-${commit}" >> rootfs/etc/issue
fi

# build the system container
echo "Building the system container"
docker build -t lfs-system .

# dump a tar archive of the system
echo "Dumping tar archive of container"
cid="`docker run -d lfs-system /bin/true`"
docker export --output="fs.tar" $cid
docker rm $cid

# extract the archive and create the initrd.bin
echo "Extract archive and create initrd.bin"
mkdir extract-fs
cd extract-fs/
tar xf ../fs.tar
rm dev/console
mknod -m 622 dev/console c 5 1
mknod -m 622 dev/tty0 c 4 0
mv vmlinuz ..
find | ( set -x; cpio -o -H newc | xz -9 --format=lzma --verbose --verbose ) > ../initramfs.xz
mv initramfs.xz initramfs.bin
cd ..
rm -rf extract-fs
rm fs.tar

# build the ISO container and dump the iso
echo "Building ISO container"
docker build -t lfs-iso -f Dockerfile.iso .
docker run --rm lfs-iso > tugger.bin

# clean up auto generated files
echo "Cleaning up"
if [ $CREATED_OSRELEASE -eq 1 ]; then
	rm rootfs/etc/os-release
fi
if [ $CREATED_ISSUE -eq 1 ]; then
	rm rootfs/etc/issue
fi
