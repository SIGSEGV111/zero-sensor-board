#!/bin/bash

set -eu

readonly P="$(dirname "$(readlink -f "$0")")"
cd "$P"

readonly RUNNER="$(readlink -f "zsb.sh")"

if test -e /etc/rc.local; then
	echo "detected Debian-like distribution"
	readonly INITSCRIPT="/etc/rc.local"
elif grep -qiF "suse" /etc/os-release; then
	echo "detected SuSE-like distribution"
	readonly INITSCRIPT="/etc/init.d/boot.local"
else
	echo "unknown distribution, cannot install"
	exit 1
fi

echo "installing '$RUNNER' into '$INITSCRIPT'"
touch "$INITSCRIPT"
chmod +x "$INITSCRIPT"
sed -i '/zsb.sh/d' "$INITSCRIPT" || true
sed -i "2i$RUNNER &" "$INITSCRIPT"

mkdir -p "/etc/zsb"
touch "/etc/zsb/location"
touch "/etc/zsb/postgres"

echo
echo "all done!"
echo
echo "*** do not forget to set this boards location in /etc/zsb/location ***"
echo "*** if required specify the connect string in /etc/zsb/postgres ***"
echo
echo
