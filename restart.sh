#!/bin/bash

set -u
set +e

# kill child processes if this script is SIGTERM'ed
trap "set -x; set +e; pgrep -a -P $$ 1>&2; pkill -P $$; kill -KILL $$; trap '' EXIT; exit 0" TERM INT QUIT HUP EXIT

for ((;;)); do
	echo "[INFO] $(date) starting '$1' '$2' '$3'" 1>&2

	# you do not want to know why this ugly construct is necessary...
	"$1" "$2" "$3" &
	wait

	echo "[WARN] $(date) '$1' exited with code=$?" 1>&2
	echo "[INFO] $(date) will restart '$1' in 10s ..." 1>&2
	sleep 10
done