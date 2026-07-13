#!/usr/bin/env bash
# Generates a Homebrew Cask file for a given release, pointing at the
# already-uploaded GitHub release zip. Only arm64 (Apple Silicon) is built
# right now -- there's no Intel build pipeline yet (see AGENTS.md) -- so this
# cask only declares that one architecture; extend it with an on_intel block
# once an amd64 build exists.
#
# Usage: macos/generate_homebrew_cask.sh <version> <zip-path> [output-dir]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 2 ]; then
	echo "Usage: $0 <version> <zip-path> [output-dir]" >&2
	exit 1
fi

VERSION="$1"
ZIP_PATH="$2"
OUTPUT_DIR="${3:-${REPO_ROOT}/build-macos/dist/Casks}"
OUTPUT_FILE="${OUTPUT_DIR}/pgadmin3.rb"

if [ ! -f "$ZIP_PATH" ]; then
	echo "error: $ZIP_PATH not found" >&2
	exit 1
fi

mkdir -p "$OUTPUT_DIR"
SHA_ARM="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

cat > "$OUTPUT_FILE" <<EOF
cask "pgadmin3" do
  version "${VERSION}"
  name "pgAdmin III"
  desc "Native PostgreSQL administration GUI (community fork of pgAdmin III)"
  homepage "https://github.com/heptau/pgadmin3"

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  url "https://github.com/heptau/pgadmin3/releases/download/v#{version}/pgAdmin3-#{version}-macos-arm64.zip"
  sha256 "${SHA_ARM}"

  app "pgAdmin III.app"

  postflight do
    system_command "/usr/bin/xattr",
                    args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/pgAdmin III.app"],
                    sudo: false
  end

  zap trash: [
    "~/Library/Preferences/postgresql",
  ]
end
EOF

echo "Generated ${OUTPUT_FILE}"
