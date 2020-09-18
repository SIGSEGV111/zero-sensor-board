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

# close STDIN and STDOUT
exec 0</dev/null 1>/dev/null

# change working dir
readonly P="$(dirname "$(readlink -f "$0")")"
cd "$P"

# load i2c interface module
modprobe i2c-dev || true

# run the LED daemon
./ledd.sh &

# login to kerberos if required
if test -e "/etc/zsb/keytab"; then
	./krenewd.sh "zsb" "/etc/zsb/keytab" &

	# wait 10s to give krenewd a chance to acquire a ticket
	# this prevents errors/warnings about missing/invalid ticket
	# in the logs during startup
	sleep 10
fi

# read config
set +e
read POSTGRES < /etc/zsb/postgres
readonly POSTGRES
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

# power-up DHT22
echo 26 > /sys/class/gpio/export || true # this might fail if the PIN was already exported before
echo out > /sys/class/gpio/gpio26/direction
echo 1 > /sys/class/gpio/gpio26/value

# run the sensor drivers and database feeder
./restart.sh ./bme280-driver/bme280-csv "/dev/i2c-1" "$LOCATION" &
./restart.sh ./dht22-spi-driver/dht22-csv "/dev/spidev0.1" "$LOCATION" &
./restart.sh ./opt3001-driver/opt3001-csv "/dev/i2c-1" "$LOCATION" 19 &
./restart.sh ./sds011-driver/sds011-csv "/dev/ttyS0" "$LOCATION" &
./restart.sh ./vz89te-driver/vz89te-csv "/dev/i2c-1" "$LOCATION" &
./restart.sh ./mlx90614-driver/mlx90614-csv "/dev/i2c-1" "$LOCATION" &
./restart.sh ./ds1820-sysfs-poller/ds1820-csv "$LOCATION" &
./restart.sh ./postgres-feeder/postgres-feeder "sensor_data_upload" "$POSTGRES" &

wait
