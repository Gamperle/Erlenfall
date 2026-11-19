#!/usr/bin/env bash
# Prepares a fresh clone or git worktree so the game and the smoke test run (#499).
#
# Order matters:
#   1. git lfs pull     - a fresh worktree has LFS pointer files, not the real models/textures.
#   2. godot --import   - builds .godot/ (imported assets and the global class cache that
#                         resolves `class_name` identifiers such as Village). Without it the
#                         smoke test fails with 'Identifier "Village" not declared'.
#   3. revert .import   - the import can rewrite tracked *.import files; they are not your change.
#
# Usage: tools/prepare_worktree.sh   (from anywhere inside the checkout)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git lfs install --local >/dev/null
git lfs pull

if grep -rIl --include='*.glb' --include='*.png' '^version https://git-lfs' assets 2>/dev/null | head -1 | grep -q .; then
	echo "Some assets are still LFS pointer files after git lfs pull." >&2
	exit 1
fi

# The import crashes now and then (#196); a second run has worked.
for attempt in 1 2 3; do
	godot --headless --path . --import && break
	echo "Import failed (attempt $attempt), retrying..." >&2
	[ "$attempt" = 3 ] && exit 1
done

if [ ! -s .godot/global_script_class_cache.cfg ]; then
	echo "Import finished but .godot/global_script_class_cache.cfg is missing." >&2
	exit 1
fi

# Revert import rewrites of tracked .import files (only those, never other changes).
git ls-files -m -z -- '*.import' | xargs -0 -r git checkout --

echo "Ready. Run: godot --headless --path . --script res://tests/smoke_test.gd"
