#!/bin/bash -u

# disable the green LED
echo none > /sys/devices/platform/leds/leds/led0/trigger

function on()
{
	echo 255 > /sys/devices/platform/leds/leds/led0/brightness
}

function off()
{
	echo 0 > /sys/devices/platform/leds/leds/led0/brightness
}

function sleep100ms()
{
	read -t 0.1
}

function blink()
{
	# blink for 10s
	for ((i=0;i<50;i++)); do
		on
		sleep100ms
		off
		sleep100ms
	done
}

rm -f /tmp/ledd.fifo
mkfifo /tmp/ledd.fifo
off

# blink the LED every time there is a new log message
tail -c 0 -f /var/log/zsb.log | for ((;;)); do
	read -r line
	blink <>/tmp/ledd.fifo
	while read -r -t 0.1 line; do continue; done
done
