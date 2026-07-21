#!/bin/bash
# Convenience launcher for a quick dev run of the macOS build -- runs the
# bare executable directly (see AGENTS.md for context), skipping the .app
# bundling `make build` does. Also wired up as `make run` on macOS.
set -euo pipefail
cd "$(dirname "$0")/build-macos"
# Ensure the docs symlink exists for the bare-binary dev-run path.
# LocatePath() falls back to loadPath + "/docs" on macOS when GetDataDir()
# doesn't contain the right files (e.g. when running outside a .app bundle).
if [ -d ../app-docs ] && [ ! -L docs ] && [ ! -f docs ]; then
	ln -s ../app-docs docs || true
fi
export DYLD_LIBRARY_PATH="${WX_COCOA_PREFIX:-$HOME/wx-cocoa-classic}/lib"
exec ./pgAdmin3 "$@"
