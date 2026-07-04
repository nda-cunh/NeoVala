#!/bin/sh
# Rebuild the compiler and push the freshly built trio to BOTH runtime
# locations the test harness resolves against:
#   - ~/.local  (LD_LIBRARY_PATH, searched before the binary RUNPATH)
#   - ./usr     (DESTDIR-installed copy that posix-test/test invokes)
#
# Why this exists: a commit bumps `git describe`, so the newly built libvala /
# libvalacodegen / valac report a new version. If any of the three copies is
# left stale, the self-hosting integrity check fails
# ("libvala X doesn't match ccodegen Y"). Run this after every rebuild that
# follows a commit — it keeps all six files in lockstep.
set -e

cd "$(dirname "$0")"

ninja -C build

LOCAL_LIB="$HOME/.local/lib"
LOCAL_BIN="$HOME/.local/bin"

for dst in "$LOCAL_LIB" "usr/lib"; do
	cp build/vala/libvala-0.58.so.0.0.0 "$dst/libvala-0.58.so.0.0.0"
	cp build/codegen/libvalacodegen.so "$dst/vala-0.58/libvalacodegen.so"
done

cp build/compiler/valac-0.58 "$LOCAL_BIN/valac-0.58"
cp build/compiler/valac-0.58 usr/bin/valac-0.58

echo "synced $(usr/bin/valac --version)"
