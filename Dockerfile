FROM tugger-chroot

# run test suites?
ENV LFS_TEST=0

# set up environment for the build

ENV PATH /bin:/usr/bin:/sbin:/usr/sbin:/tools/bin
ENV HOME /root
ENV TERM xterm

# create required directories

RUN ["/tools/bin/bash", "+h", "-c", "mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt} \
    && mkdir -pv /{media/{floppy,cdrom},sbin,srv,var} \
    && install -dv -m 0750 /root \
    && install -dv -m 1777 /tmp /var/tmp \
    && mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src} \
    && mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man} \
    && mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo} \
    && mkdir -v  /usr/libexec \
    && mkdir -pv /usr/{,local/}share/man/man{1..8} \
    && ln -sv lib /lib64 \
    && ln -sv lib /usr/lib64 \
    && ln -sv lib /usr/local/lib64 \
    && mkdir -v /var/{log,mail,spool} \
    && ln -sv /run /var/run \
    && ln -sv /run/lock /var/lock \
    && mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local"]

# create links for files that dont exist yet
# we must use bash +h so that the new executables will be used as we replace them

RUN ["/tools/bin/bash", "+h", "-c", "ln -sv /tools/bin/{bash,cat,echo,pwd,stty} /bin \
    && ln -sv /tools/bin/perl /usr/bin \
    && ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib \
    && ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib \
    && sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la \
    && ln -sv bash /bin/sh"]

# make a link for /etc/mtab

RUN ["/bin/bash", "+h", "-c", "rm -r /etc/mtab && ln -sv /proc/self/mounts /etc/mtab"]

# create password and group files

ADD passwd /etc/passwd
ADD group /etc/group

# initialise log files with proper permissions

RUN ["/bin/bash", "+h", "-c", "touch /var/log/{btmp,lastlog,faillog,wtmp} \
    && chgrp -v utmp /var/log/lastlog \
    && chmod -v 664  /var/log/lastlog \
    && chmod -v 600  /var/log/btmp"]

# install the final system glibc

WORKDIR /sources

# linux headers

RUN ["/bin/bash", "+h", "-c", "tar -xf linux-*.tar.xz -C /tmp/ \
    && cd /tmp/linux-* \
    && make mrproper \
    && make INSTALL_HDR_PATH=dest headers_install \
    && find dest/include -type f -name .install -delete \
    && find dest/include -type f -name ..install.cmd -delete \
    && cd /tmp \
    && rm -rf /tmp/linux-*"]

# man pages

RUN ["/bin/bash", "+h", "-c", "tar -xf man-pages-*.tar.xz -C /tmp/ \
    && cd /tmp/man-pages-* \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/man-pages-*"]

# glibc

RUN ["/bin/bash", "+h", "-c", "tar -xf glibc-*.tar.xz -C /tmp/ \
    && cd /tmp/glibc-* \
    && patch -Np1 -i /sources/glibc-2.24-fhs-1.patch \
    && mkdir -v build \
    && cd build \
    && ../configure --prefix=/usr          \
        --enable-kernel=2.6.32 \
        --enable-obsolete-rpc \
    && make \
    && if [ $LFS_TEST -eq 1 ]; then make check; fi \
    && touch /etc/ld.so.conf \
    && make install \
    && cp -v ../nscd/nscd.conf /etc/nscd.conf \
    && mkdir -pv /var/cache/nscd \
    && mkdir -pv /usr/lib/locale \
    && localedef -i en_GB -f UTF-8 en_GB.UTF-8 \
    && localedef -i en_US -f ISO-8859-1 en_US \
    && localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && cd /tmp \
    && rm -rf /tmp/glibc-*"]

# configure glibc

ADD nsswitch.conf /etc/nsswitch.conf
ADD ld.so.conf /etc/ld.so.conf
RUN ["/bin/bash", "+h", "-c", "mkdir -pv /etc/ld.so.conf.d"]

# tzdata

RUN ["/bin/bash", "+h", "-c", "mkdir -pv /tmp/tzdata \
    && tar -xf tzdata2016f.tar.gz -C /tmp/tzdata \
    && cd /tmp/tzdata \
    && ZONEINFO=/usr/share/zoneinfo \
    && mkdir -pv $ZONEINFO/posix \
    && mkdir -pv $ZONEINFO/right \
    && for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward pacificnew systemv; do \
        zic -L /dev/null   -d $ZONEINFO       -y 'sh yearistype.sh' ${tz} \
        && zic -L /dev/null   -d $ZONEINFO/posix -y 'sh yearistype.sh' ${tz} \
        && zic -L leapseconds -d $ZONEINFO/right -y 'sh yearistype.sh' ${tz} \
    ;done \
    && cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO \
    && zic -d $ZONEINFO -p America/New_York \
    && unset ZONEINFO \
    && cd /tmp \
    && rm -rf /tmp/tzdata"]

# adjust toolchain to use the final C library

RUN ["/bin/bash", "+h", "-c", "mv -v /tools/bin/{ld,ld-old} \
    && mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old} \
    && mv -v /tools/bin/{ld-new,ld} \
    && ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld"]

RUN gcc -dumpspecs | sed -e 's@/tools@@g'\
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > \
    `dirname $(gcc --print-libgcc-file-name)`/specs

RUN echo 'int main(){}' > dummy.c \
    && cc dummy.c -v -Wl,--verbose &> dummy.log \
    && readelf -l a.out | grep ': /lib' \
    && grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log \
    && grep -B1 '^ /usr/include' dummy.log \
    && grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' \
    && grep "/lib.*/libc.so.6 " dummy.log \
    && grep found dummy.log \
    && rm -v dummy.c a.out dummy.log

# build the kernel

RUN ["/bin/bash", "+h", "-c", "tar -xf bc-*.tar.bz2 -C /tmp/ \
    && cd /tmp/bc-* \
    && ./configure --prefix=/tools \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/bc-*"]

RUN ["/bin/bash", "+h", "-c", "tar -xf linux-*.tar.xz -C /tmp/ \
    && cd /tmp/linux-* \
    && make mrproper \
    && make defconfig \
    && make -j 8 \
    && cp arch/x86/boot/bzImage /vmlinuz \
    && make modules_install \
    && cd /tmp \
    && rm -rf /tmp/linux-*"]

# anything from /tools that will be linked by a program in the final system
# must be replaced now to create the final toolchain and avoid linking with
# the /tools versions, which will be removed at the end of the build process

# now we can continue building the rest of the system

ADD sources /sources/

# busybox

RUN tar -xf busybox-*.tar.bz2 -C /tmp/ \
    && cd /tmp/busybox-* \
    && make defconfig \
    && make \
    && make PREFIX=/ CONFIG_PREFIX=/ install \
    && cd /tmp \
    && rm -rf /tmp/busybox-*

# iptables

RUN tar -xf iptables-*.tar.bz2 -C /tmp/ \
    && cd /tmp/iptables-* \
    && ./configure --prefix=/usr \
        --sbindir=/sbin \
        --disable-nftables \
        --enable-libipq \
        --with-xtlibdir=/lib/xtables \
    && make \
    && make install \
    && ln -sfv ../../sbin/xtables-multi /usr/bin/iptables-xml \
    && for file in ip4tc ip6tc ipq iptc xtables; do \
        mv -v /usr/lib/lib${file}.so.* /lib \
        && ln -sfv ../../lib/$(readlink /usr/lib/lib${file}.so) /usr/lib/lib${file}.so \
    ;done \
    && cd /tmp \
    && rm -rf /tmp/iptables-*

# xz

RUN tar -xf xz-*.tar.xz -C /tmp/ \
    && cd /tmp/xz-* \
    && sed -e '/mf\.buffer = NULL/a next->coder->mf.size = 0;' \
        -i src/liblzma/lz/lz_encoder.c \
    && ./configure --prefix=/usr    \
        --disable-static \
        --docdir=/usr/share/doc/xz-5.2.2 \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/xz-*

# nodejs

RUN tar -xf node-*.tar.xz -C /tmp/ \
    && cd /tmp/node-* \
    && cp -r bin /usr/ \
    && cp -r include /usr/ \
    && cp -r lib /usr/ \
    && cp -r share /usr/ \
    && cd /tmp \
    && rm -rf /tmp/node-*

# docker

RUN gunzip docker-*.tgz \
    && tar -xf docker-*.tar -C /tmp/ \
    && mv /tmp/docker/docker* /usr/bin/ \
    && rm -rf /tmp/docker

# cleaning up the image

RUN rm -f /usr/lib/lib{bfd,opcodes}.a \
    && rm -f /usr/lib/libbz2.a \
    && rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a \
    && rm -f /usr/lib/libltdl.a \
    && rm -f /usr/lib/libfl.a \
    && rm -f /usr/lib/libfl_pic.a \
    && rm -f /usr/lib/libz.a

RUN rm -rf /usr/lib/*.a

RUN rm -rf /usr/include/*

RUN rm -rf /usr/share/doc/*

RUN rm -rf /usr/share/man/*

# strip binaries

RUN ["/tools/bin/bash", "-c", "/tools/bin/find /usr/lib -type f -name *.a \
   -exec /tools/bin/strip --strip-debug {} ';'"]

RUN ["/tools/bin/bash", "-c", "/tools/bin/find /lib /usr/lib -type f -name *.so* \
   -exec /tools/bin/strip --strip-unneeded {} ';'"]

RUN ["/tools/bin/bash", "-c", "/tools/bin/find /{bin,sbin} /usr/{bin,sbin,libexec} -type f \
    -exec /tools/bin/strip --strip-all {} ';'"]

# find any binaries linked against /tools, or symlinks to /tools, and remove

RUN cp /tools/lib/libstdc++.so /usr/lib/libstdc++.so
RUN cp /tools/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
RUN cp /tools/lib/libgcc_s.so /usr/lib/libgcc_s.so
RUN cp /tools/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1

# remove /sources, /tools

WORKDIR /
RUN rm -rf /sources
RUN rm -rf /tools

# system configuration

ADD init /init
ADD init2 /init2
ADD fstab /etc/fstab

RUN echo root:root | chpasswd

ADD cgroupfs-mount /sbin/cgroupfs-mount
RUN chmod a+x /sbin/cgroupfs-mount
