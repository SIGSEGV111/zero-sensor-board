#!/bin/bash

if ! test -x "$1"; then
	echo "[WARN] program '$1' does not exist (or is not executeable), assuming this is intentional and exiting without error"
	exit 0
fi

set +e

# kill child processes if this script is SIGTERM'ed
trap "set -x; set +e; pgrep -a -P $$ 1>&2; pkill -P $$; kill -KILL $$; trap '' EXIT; exit 0" TERM INT QUIT HUP EXIT

for ((;;)); do
	echo "[INFO] $(date) starting '$1' '$2' '$3'" 1>&2

	# you do not want to know why this ugly construct is necessary...
	"$1" "$2" "$3" $4 0<>/tmp/zsb.csv 1>>/tmp/zsb.csv &
	wait
	code=$?

	echo "[WARN] $(date) '$1' exited with code=$code" 1>&2
	echo "[INFO] $(date) will restart '$1' in 10s ..." 1>&2
	sleep 10
done
