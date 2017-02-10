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

# create password and group files early for tests

ADD rootfs/etc/passwd /etc/passwd
ADD rootfs/etc/group /etc/group

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

ADD sources /sources/

# the kernel requires bc and openssl but leave them in the final
# system because they are useful and relatively small

RUN ["/bin/bash", "+h", "-c", "tar -xf bc-*.tar.bz2 -C /tmp/ \
    && cd /tmp/bc-* \
    && ./configure --prefix=/tools \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/bc-*"]

RUN ["/bin/bash", "+h", "-c", "tar -xf openssl-*.tar.gz -C /tmp/ \
    && cd /tmp/openssl-* \
    && ./config --prefix=/usr \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared \
    && make depend \
    && make \
    && make MANDIR=/usr/share/man MANSUFFIX=ssl install \
    && cd /tmp \
    && rm -rf /tmp/openssl-*"]

ADD kernel-config /tmp/kernel-config

RUN ["/bin/bash", "+h", "-c", "tar -xf linux-*.tar.xz -C /tmp/ \
    && cd /tmp/linux-* \
    && make mrproper \
    && cp /tmp/kernel-config .config \
    && make -j 8 \
    && cp arch/x86/boot/bzImage /vmlinuz \
    && make modules_install \
    && cd /tmp \
    && rm -rf /tmp/linux-*"]

# anything from /tools that will be linked by a program in the final system
# must be replaced now to create the final toolchain and avoid linking with
# the /tools versions, which will be removed at the end of the build process

# now we can continue building the rest of the system

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

# ca-certificates (required for docker registry with ssl)

RUN cp cacert.pem /etc/ssl/certs/
RUN cat /etc/ssl/certs/*.pem > /etc/ssl/certs/ca-certificates.crt \
    && sed -i -r '/^#.+/d' /etc/ssl/certs/ca-certificates.crt

# kmod (busybox modutils will not load lustre correctly)

RUN tar -xf kmod-*.tar.xz -C /tmp/ \
    && cd /tmp/kmod-* \
    && ./configure --prefix=/usr \
            --bindir=/bin \
            --sysconfdir=/etc \
            --with-rootlibdir=/lib \
    && make \
    && make install \
    && for target in depmod insmod lsmod modinfo modprobe rmmod; do \
        ln -sfv ../bin/kmod /sbin/$target \
    ;done \
    && ln -sfv kmod /bin/lsmod \
    && cd /tmp \
    && rm -rf /tmp/kmod-*

# eudev

# requires gperf and pkg-config (to find kmod)

RUN tar -xf gperf-*.tar.gz -C /tmp/ \
    && cd /tmp/gperf-* \
    && ./configure --prefix=/usr \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/gperf-*

RUN tar -xf pkg-config-*.tar.gz -C /tmp/ \
    && cd /tmp/pkg-config-* \
    && ./configure --prefix=/usr \
            --with-internal-glib       \
            --disable-compile-warnings \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.1 \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/pkg-config-*

RUN tar -xf eudev-*.tar.gz -C /tmp/ \
    && cd /tmp/eudev-* \
    && KMOD_CFLAGS="-I/usr/include" \
    KMOD_LIBS="-L/lib -lkmod" \
        ./configure --prefix=/ \
            --bindir=/sbin          \
            --sbindir=/sbin         \
            --libdir=/usr/lib       \
            --sysconfdir=/etc       \
            --libexecdir=/lib       \
            --with-rootprefix=/     \
            --with-rootlibdir=/lib  \
            --disable-manpages       \
            --disable-static        \
            --disable-selinux \
            --enable-kmod \
            --disable-blkid \
            --disable-introspection \
    && make \
    && mkdir -pv /lib/udev/rules.d \
    && mkdir -pv /etc/udev/rules.d \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/eudev-*

# lustre-utils

# lustre requires automake, autoconf and libtool - add them to /tools

RUN tar -xf libtool-*.tar.xz -C /tmp/ \
    && cd /tmp/libtool-* \
    && ./configure --prefix=/tools \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/libtool-*

RUN tar -xf autoconf-*.tar.xz -C /tmp/ \
    && cd /tmp/autoconf-* \
    && ./configure --prefix=/tools \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/autoconf-*

RUN tar -xf automake-*.tar.xz -C /tmp/ \
    && cd /tmp/automake-* \
    && ./configure --prefix=/tools \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/automake-*

RUN tar -xf v2_9_0.tar.gz -C /tmp/ \
    && cd /tmp/lustre-* \
    && sh autogen.sh \
    && ./configure --prefix=/usr \
        --disable-server \
        --disable-modules \
        --disable-client \
        --disable-tests \
        --disable-manpages \
    && make undef.h \
    && make CFLAGS=-Wno-error \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/lustre-*

# init system

RUN npm install -g init8js@0.0.7

# the example API middleware

RUN npm install -g tugger-service@0.0.2

# use the tugger greeter

RUN npm install -g tugger-greeter@0.0.7

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

RUN rm -rf /root/.npm

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

COPY rootfs /

RUN echo root:root | chpasswd

RUN depmod -a `ls /lib/modules | head -n 1`
