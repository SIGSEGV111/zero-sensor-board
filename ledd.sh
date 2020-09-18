#!/bin/bash -eu

# disable the green LED
echo none > /sys/devices/platform/leds/leds/led0/trigger
echo 255 > /sys/devices/platform/leds/leds/led0/brightness

# blink the LED every time there is a new log message

function off()
{
	echo 255 > /sys/devices/platform/leds/leds/led0/brightness
}

function on()
{
	echo 0 > /sys/devices/platform/leds/leds/led0/brightness
}

function blink()
{
	for ((i=0;i<3;i++)); do
		on
		sleep 0.1
		off
		sleep 0.1
	done
}

tail -c 0 -f /var/log/zsb.log | while read -r msg; do
	blink
done
