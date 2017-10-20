# FruitOS Package Repository Builder

This repository contains necessary files to build a package
repository for FruitOS.

Requirements:
- FruitOS (>0.0.3)
- Makefile


To Build:

1. Copy Fruit private key file to `fruit-apk-key.rsa` which
   will be used to sign the packages and repository's index
   file.

2. Invoke command `$ make`. This will install necessary files,
   build packages or download them from other repositories.

If everything works well then all packages are available at
`target/packages/armhf/`. You can publish the packages by
serving that directory through an HTTP server (e.g. Nginx).
