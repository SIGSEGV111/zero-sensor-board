#!/bin/bash

set -eu

# kill child processes if this script is SIGTERM'ed
trap "set -x; set +e; pgrep -a -P $$ 1>&2; pkill -P $$; kill -KILL $$" TERM INT QUIT HUP EXIT

for ((;;)); do
	echo "[INFO] $(date) starting '$1' '$2' '$3'"
	set +e
	set -x
	"$1" "$2" "$3" &
	set +x
	set -e
	wait
	echo "[WARN] $(date) '$1' crashed with code=$?"
	echo "[INFO] $(date) will restart '$1' in 1m ..."
	sleep 10
done
