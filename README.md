# tugger system

This Dockerfile will build the tugger distribution using the [tugger-toolchain](https://github.com/kxes/tugger-toolchain).

Unless you want to rebuild the system from source, you are probably looking to download the ISO.

## what is tugger

`tugger` is a not-very-opinionated, minimal datacentre OS. It provides only a container runtime and basic system initialisation services. It does not provide any management middleware, instead, you are expected to roll your own using Node.js.

Distinguishing features:

- longterm kernel (currently 4.4.47)
- Docker Engine
- Node.js
- < 40MB compressed
