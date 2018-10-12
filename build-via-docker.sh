#!/bin/sh
DOCKER_ARCH=${DOCKER_ARCH:-armhf}

# If you run:
#   docker run --rm --name squid adricu/alpine-squid
# and set DOCKER_SQUID_CONTAINER=squid
# then you can avoid repeated downloads of a lot of alpine packages.
#
DOCKER_SQUID_CONTAINER=${DOCKER_SQUID_CONTAINER:-""}
if [ "$DOCKER_SQUID_CONTAINER" = "" ]; then
    docker_squid_opts=""
else
    docker_squid_opts="--link ${DOCKER_SQUID_CONTAINER}:squid -e http_proxy=http://squid:3128/"
fi

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
    ${docker_squid_opts} \
    multiarch/alpine:${DOCKER_ARCH}-edge \
    /bin/sh -c "cd /media/data/fruitos/apks && sh $tmpscript"
