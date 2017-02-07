# tugger system

This repository contains the sources required to build the tugger distribution using the [tugger-toolchain](https://github.com/kxes/tugger-toolchain).

Precompiled ISO, kernel and intiramfs are available on the releases page. You probably want to download these.

## what is tugger

`tugger` is a very small and very fast Linux distribution intended to be used as a base to build your data centre or HPC bare metal OS.

It typically does not require installation and runs completely from RAM.

It provides only a container runtime and basic system initialisation services. It does not provide any management middleware, instead, you are expected to roll your own. 
Node.js is included as a convienient framework for building an API using web technologies (an example is available here [tugger-service](https://github.com/kxes/tugger-service)).

Distinguishing features:

- longterm kernel (currently 4.4.47)
- Docker Engine
- Node.js
- Lustre parallel filesystem client
- < 40MB compressed
- full source and easy to understand toolchain

## building it

You need to build the toolchain first (link at the top).

Then, populate the sources directory by downloading all the files in `wget-list`.

Finally, run `build.sh`. The container's filesystem itself is the final initramfs image. This script will dump it, extract the kernel and create the `initramfs.xz` file.
