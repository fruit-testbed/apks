#!/bin/sh
DOCKER_ARCH=${DOCKER_ARCH:-armhf}
exec \
    docker run -it --rm -v $(realpath $(dirname "$0")/..):/media/data/fruitos \
    multiarch/alpine:${DOCKER_ARCH}-edge \
    /bin/sh -c 'apk update && apk add make git && cd /media/data/fruitos/apks && rm -f .prepare && make '"$@"
