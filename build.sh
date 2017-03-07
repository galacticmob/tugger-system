#!/bin/bash
# Build script for the tugger-system

# This script will:
# - update the os-release with the current info from git
# - build the system container (make sure you built toolchain first)
# - build the iso image

commit="`git log --pretty=format:'%h' -n 1`"
echo "NAME=tugger" > rootfs/etc/os-release
echo "VERSION=git-${commit}" >> rootfs/etc/os-release
echo "ID=tugger" >> rootfs/etc/os-release
echo "VERSION_ID=git-${commit}" >> rootfs/etc/os-release
echo "PRETTY_NAME=tugger OS git-${commit}" >> rootfs/etc/os-release

docker build -t lfs-system .

cid="`docker run -d lfs-system /bin/true`"
docker export --output="fs.tar" $cid
docker rm $cid

mkdir extract-fs
cd extract-fs/
tar xf ../fs.tar
rm dev/console
mknod -m 622 dev/console c 5 1
mknod -m 622 dev/tty0 c 4 0
mv vmlinuz ..
find | ( set -x; cpio -o -H newc | xz -1 --format=lzma --verbose --verbose ) > ../initramfs.xz
cd ..
rm -rf extract-fs
rm fs.tar

docker build -t lfs-iso -f Dockerfile.iso .
docker run --rm lfs-iso > tugger.iso
