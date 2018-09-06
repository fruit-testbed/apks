#!/bin/sh
exec \
    docker run -it --rm -v $(realpath $(dirname "$0")/..):/media/data/fruitos \
    multiarch/alpine:armhf-edge \
    /bin/sh -c 'apk update && apk add make git && cd /media/data/fruitos/apks && rm -f .prepare && make'
