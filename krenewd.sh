#!/bin/bash -eu

readonly krb_user="$1"
readonly krb_keytab="$2"

for ((;;)); do
	if ! kinit -p "$krb_user" -R; then
		/usr/bin/kinit -p "$krb_user" -V -k -t "$krb_keytab" || true
	fi
	sleep 1m
done
