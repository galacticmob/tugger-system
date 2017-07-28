# tugger system

This repository contains the sources required to build the tugger distribution using the [tugger-toolchain](https://github.com/kxes/tugger-toolchain).

Precompiled ISO, kernel and intiramfs are available on the releases page. You probably want to download these.

## what is tugger

`tugger` is a very small and very fast OS intended to be used as a base to build Galaxy.PRC

It typically installs in seconds and runs completely from RAM.

It provides only a container runtime and basic system initialisation services. It does not provide any management middleware, instead, you are expected to roll your own. 
Node.js is included as a convienient framework for building an API using web technologies (an example is available here [tugger-service](https://github.com/kxes/tugger-service)).
Fluent Bit is included to centralise logging and metric collection, avoiding exhausting memory when running from VFS.

The default build system includes:

- longterm kernel
- Docker Engine
- Node.js
- Fluent Bit
- < 50MB compressed
- full source and easy to understand toolchain

## building it

You need to build the toolchain first (link at the top).

Then, populate the sources directory by downloading all the files in `wget-list`.

Place any firmware files to be included in the firmware directory (most firmware can be found in the [linux-firmware](http://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/tree/) repository).

Finally, run `build.sh`. The container's filesystem itself is the final initramfs image. This script will dump it, extract the kernel and create the `initramfs.bin` file.
