# tugger system

This Dockerfile will build the tugger distribution using the [tugger-toolchain](https://github.com/kxes/tugger-toolchain).

Unless you want to rebuild the system from source, you are probably looking to download the ISO.

## what is tugger

`tugger` is a less-opinionated, minimal datacentre OS. It provides only a container runtime and basic system initialisation services. It does not provide any management middleware, instead, you are expected to roll your own using Node.js.

Distinguishing features:

- longterm kernel (currently 4.4.47)
- Docker Engine
- Node.js
- Lustre parallel filesystem client
- < 40MB compressed

## building it

You need to build the toolchain first (link at the top).

Then, populate the sources directory by downloading all the files in `wget-list`.

Finally, run `build.sh`. The container's filesystem itself is the final initramfs image. This script will dump it, extract the kernel and create the `initramfs.xz` file.
