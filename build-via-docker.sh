#!/bin/sh
DOCKER_ARCH=${DOCKER_ARCH:-armhf}

cd "$(dirname "$0")"

tmpscript=$(mktemp tmpscript.XXXXXXXXXX)
trap "rm -f $tmpscript" 0

cat > $tmpscript <<EOF
set -xe
apk update
apk add make git
cd /media/data/fruitos/apks
rm -f .prepare
make $@
EOF

docker run -it --rm -v $(realpath ..):/media/data/fruitos \
    multiarch/alpine:${DOCKER_ARCH}-edge \
    /bin/sh -c "cd /media/data/fruitos/apks && sh $tmpscript"
