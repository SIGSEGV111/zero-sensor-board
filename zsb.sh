#!/bin/bash

set -eu

# acquire lock
exec 3>>/tmp/zsb.lock
if ! flock --exclusive 3; then
	echo "[WARN] $(date) script already running" 1>&2
	exit 2
fi

echo "[INFO] $(date) logging to /var/log/zsb.log" 1>&2
# comment out the next line to get debug output to the console
exec 2>/var/log/zsb.log

# buffer file
exec 0</dev/null
exec 1>>/tmp/zsb.csv

# change working dir
readonly P="$(dirname "$(readlink -f "$0")")"
cd "$P"

# read config
set +e
read POSTGRES < /etc/zsb/postgres
set -e
read LOCATION < /etc/zsb/location
readonly LOCATION
if test -z "$LOCATION"; then
	echo "[ERROR] $(date) no location set in /etc/zsb/location!" 1>&2
	exit 1
fi

# kill child processes if this script is SIGTERM'ed
trap "set -x; set +e; pgrep -a -P $$ 1>&2; pkill -P $$; trap '' EXIT; exit 0" TERM EXIT QUIT HUP INT

echo "[INFO] $(date) zero sensor board @ '$LOCATION' starting up" 1>&2

./restart.sh ./sds011-driver/sds011-csv "/dev/ttyS0" "$LOCATION" &
./restart.sh ./vz89te-driver/vz89te-csv "/dev/i2c-1" "$LOCATION" &
#./restart.sh ./bme280-driver/bme280-csv "/dev/i2c-1" "$LOCATION" &
./restart.sh ./opt3001-driver/opt3001-csv "/dev/i2c-1" "$LOCATION" 5 &

if test -e /etc/zsb/keytab; then kinit -p zsb -V -k -t /etc/zsb/keytab; fi

./restart.sh ./postgres-feeder/postgres-feeder "sensor_data_upload" "$POSTGRES" <>/tmp/zsb.csv >/dev/null &

wait
