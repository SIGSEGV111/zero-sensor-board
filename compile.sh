#!/bin/bash -eu

# debian/ubuntu/raspbian/etc. has the postgres lib in a differentr location than suse
if ! test -e /usr/include/pgsql; then
	ln -vsnf postgresql /usr/include/pgsql || true
fi

if ! test -e /usr/include/pgsql/libpq-fe.h; then
	echo '*** it seems you are missing the postgres library and development files ***' 1>&2
fi

readonly n="$(find -name Makefile | wc -l)"
if (($n < 2)); then
	echo '******************************************'
	echo '*** it seems that you forgot to run    ***'
	echo '*** $> git submodule update --init     ***'
	echo '*** after you cloned this repository   ***'
	echo '******************************************'
fi 1>&2

# build all folders that have a Makefile
for m in */Makefile; do
	d="$(dirname "$m")"
	make -C "$d"
done
