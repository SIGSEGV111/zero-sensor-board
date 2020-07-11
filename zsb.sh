#!/bin/bash

set -eu
echo "[INFO] $(date) logging to /var/log/zsb.log" 1>&2
exec 2>/var/log/zsb.log
exec 1>>/tmp/zsb.csv
exec 0</tmp/zsb.csv
readonly P="$(dirname "$(readlink -f "$0")")"
cd "$P"

read LOCATION < /etc/zsb/location
readonly LOCATION
if test -z "$LOCATION"; then
	echo "[ERROR] $(date) no location set in /etc/zsb/location!" 1>&2
	exit 1
fi

echo "[INFO] $(date) zero sensor board @ '$LOCATION' starting up" 1>&2

function restart_always()
{
	for(;;); do
		echo "[INFO] $(date) starting '$1' '$2' '$LOCATION'"
		"$1" "$2" "$LOCATION"
		echo "[WARN] $(date) '$1' crashed with code=$?"
		echo "[INFO] $(date) will restart '$1' in 1m ..."
		sleep 1m
	done
}

restart_always ./sds011-driver/sds011-csv "/dev/ttyS0" &
restart_always ./vz89te-driver/vz89te-csv "/dev/i2c-1" &
#restart_always ./bme280-driver/bme280-csv "/dev/i2c-1" &
#restart_always ./opt3001-driver/opt3001-csv "/dev/i2c-1" &

restart_always ./postgres-feeder/postgres-feeder &
