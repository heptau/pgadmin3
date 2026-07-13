#!/bin/bash
# Convenience launcher for the macOS build (see AGENTS.md for context).
# The binary isn't bundled as a .app yet, so it needs to be told where to
# find the locally-built wxWidgets .dylibs at runtime.
set -euo pipefail
cd "$(dirname "$0")/build-macos"
export DYLD_LIBRARY_PATH=/Users/zv/wx-cocoa-classic/lib
exec ./pgAdmin3 "$@"
