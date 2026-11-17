#!/bin/bash
# Makes the missing TRELLIS.2 models of a batch on the asset PC, a few at a time, retrying dropped connections.
# Usage: build_batch.sh BATCH [GROUP_SIZE] [TRIES]     ASSET_PC=user@host must be set, for example sshuser@192.168.1.5
# Pictures are read from BATCH\input on the PC and finished models from BATCH\trellis, so a rerun picks up where it stopped.
# Run it in the background (nohup or run_in_background) so it outlives the terminal. Exit code 1 means models are still missing.
set -u
batch=${1:?usage: build_batch.sh BATCH [GROUP_SIZE] [TRIES]}
size=${2:-4}
tries=${3:-3}
host=${ASSET_PC:?set ASSET_PC to the SSH login of the asset PC}
root='D:\erlenfall-assets'
# -n keeps ssh from reading the rest of the list from stdin. The keep-alive turns a dead connection into a failure we can retry.
remote() { ssh -n -o BatchMode=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=6 "$host" "$1" 2>&1 | tr -d '\r' | grep -v -i -E 'quantum|store now|server may'; }
# Names of the pictures that have no model yet.
missing() {  # runs in a subshell, so a failure is checked by the caller
	local wanted done
	wanted=$(remote "Get-ChildItem '$root\\$batch\\input' -Filter *.png | ForEach-Object { \$_.BaseName }" | grep -E '^[A-Za-z0-9_]+$' | LC_ALL=C sort)
	done=$(remote "if (Test-Path '$root\\$batch\\trellis') { Get-ChildItem '$root\\$batch\\trellis' -Filter *.glb | ForEach-Object { \$_.BaseName } }" | grep -E '^[A-Za-z0-9_]+$' | LC_ALL=C sort)
	[ -n "$wanted" ] || { echo "no pictures found in $root\\$batch\\input" >&2; exit 2; }
	LC_ALL=C comm -23 <(echo "$wanted") <(echo "$done") | { grep -v '^$' || true; }
}

for attempt in $(seq 1 "$tries"); do
	todo=$(missing) || exit 2
	[ -z "$todo" ] && { echo "$batch: all models are made"; exit 0; }
	echo "attempt $attempt: $(echo "$todo" | wc -l) models to make"
	while read -r -a group; do
		names=$(IFS=,; echo "${group[*]}")
		echo "making $names"
		ssh -n -o BatchMode=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=6 "$host" \
			"powershell -NoProfile -ExecutionPolicy Bypass -File $root\\run_trellis.ps1 -Batch $batch -Names $names" 2>&1 | tr -d '\r' | grep -v -i -E 'quantum|store now|server may' | tail -3
	done < <(echo "$todo" | xargs -n "$size")
done

todo=$(missing) || exit 2
if [ -n "$todo" ]; then
	echo "$batch: still missing after $tries attempts:"
	echo "$todo"
	exit 1
fi
echo "$batch: all models are made"
