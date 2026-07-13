#!/bin/bash
# Convenience launcher for a quick dev run of the macOS build -- runs the
# bare executable directly (see AGENTS.md for context), skipping the .app
# bundling `make build` does. Also wired up as `make run` on macOS.
set -euo pipefail
cd "$(dirname "$0")/build-macos"
export DYLD_LIBRARY_PATH="${WX_COCOA_PREFIX:-$HOME/wx-cocoa-classic}/lib"
exec ./pgAdmin3 "$@"
