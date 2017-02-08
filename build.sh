#!/bin/bash

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
find | ( set -x; cpio -o -H newc | xz -9 --format=lzma --verbose --verbose ) > ../initramfs.xz
cd ..
rm -rf extract-fs
rm fs.tar

docker build -t lfs-iso -f Dockerfile.iso .
docker run --rm lfs-iso > tugger.iso
