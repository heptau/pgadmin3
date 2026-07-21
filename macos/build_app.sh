#!/bin/bash
# Assemble build-macos/pgAdmin3 (a bare executable + system dylib paths) into
# a real double-clickable "pgAdmin III.app" bundle: copies the wxWidgets/etc
# dylibs it depends on into Contents/Frameworks, rewrites all the load
# commands to reference them relative to the bundle (so no DYLD_LIBRARY_PATH
# is needed at runtime), and ad-hoc code-signs everything (required for
# unsigned binaries to run on Apple Silicon).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$REPO_ROOT/build-macos}"
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-12.0}"

BIN_SRC="$BUILD_DIR/pgAdmin3"
if [ ! -x "$BIN_SRC" ]; then
	echo "error: $BIN_SRC not found -- build it first (cmake --build $BUILD_DIR)" >&2
	exit 1
fi

APP_DIR="$BUILD_DIR/pgAdmin III.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
FRAMEWORKS_DIR="$CONTENTS/Frameworks"
SHAREDSUPPORT_DIR="$CONTENTS/SharedSupport"

echo "Assembling $APP_DIR ..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$SHAREDSUPPORT_DIR"

cp "$BIN_SRC" "$MACOS_DIR/pgAdmin3"
chmod u+w "$MACOS_DIR/pgAdmin3"

# Resolve a possibly-symlinked path to the real underlying file. macOS's
# built-in readlink has no -f, so do it manually. Needed because e.g.
# libwx_osx_cocoau_core-3.3.dylib -> ...-3.3.3.dylib -> ...-3.3.3.0.0.dylib
# (the actual file): without following that chain, different libraries that
# reference it under different symlink names would each get bundled as their
# own separate copy, loading the "same" library twice under two identities
# (duplicate wx RTTI/ObjC class registration -> asserts/crashes at runtime).
canonicalize() {
	local p="$1" link
	while [ -L "$p" ]; do
		link="$(readlink "$p")"
		case "$link" in
			/*) p="$link" ;;
			*) p="$(dirname "$p")/$link" ;;
		esac
	done
	echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
}

# Resolve one dependency string (as printed by `otool -L`) to an absolute,
# canonical path, given the ORIGINAL (not-yet-copied) file that references it
# -- some Homebrew dylibs (e.g. libwebp -> libsharpyuv) use @rpath/@loader_path
# references with an LC_RPATH relative to their own original location, which
# only resolves correctly there, not once the file has been moved into
# Contents/Frameworks. Prints nothing if it's a system lib to be left alone.
resolve_dep() {
	local dep="$1" src="$2" srcdir rp rpaths candidate
	srcdir="$(dirname "$src")"
	case "$dep" in
		/usr/lib/*|/System/*) return ;;
		@executable_path/*) candidate="$srcdir/${dep#@executable_path/}" ;;
		@loader_path/*) candidate="$srcdir/${dep#@loader_path/}" ;;
		@rpath/*)
			rpaths=$(otool -l "$src" | awk '/cmd LC_RPATH/{getline; getline; print $2}')
			for rp in $rpaths; do
				rp="${rp/@loader_path/$srcdir}"
				rp="${rp/@executable_path/$srcdir}"
				if [ -f "$rp/${dep#@rpath/}" ]; then
					canonicalize "$rp/${dep#@rpath/}"
					return
				fi
			done
			return
			;;
		*) candidate="$dep" ;;
	esac
	canonicalize "$candidate"
}

# Bash on macOS defaults to 3.2 (no associative arrays), so track already
# bundled libraries as a plain space-separated string instead.
PROCESSED=" "

# Recursively bundle every non-system dylib this binary (transitively)
# depends on into Contents/Frameworks, rewriting each reference in $target
# to @executable_path/../Frameworks/...
bundle_deps() {
	local target="$1" original="$2"
	local dep base dest resolved
	while IFS= read -r dep; do
		resolved="$(resolve_dep "$dep" "$original")"
		[ -z "$resolved" ] && continue
		base="$(basename "$resolved")"
		dest="$FRAMEWORKS_DIR/$base"
		case "$PROCESSED" in
			*" $base "*) ;;
			*)
				PROCESSED="$PROCESSED$base "
				cp "$resolved" "$dest"
				chmod u+w "$dest"
				install_name_tool -id "@executable_path/../Frameworks/$base" "$dest"
				bundle_deps "$dest" "$resolved"
				;;
		esac
		install_name_tool -change "$dep" "@executable_path/../Frameworks/$base" "$target"
	done < <(otool -L "$original" | tail -n +2 | awk '{print $1}')
}
bundle_deps "$MACOS_DIR/pgAdmin3" "$BIN_SRC"

# Build AppIcon.icns from the existing Windows .ico (only a 256x256 source,
# so the larger slots are just upscaled -- good enough for local use, worth
# replacing with real multi-resolution art later).
ICON_TMP="$(mktemp -d)"
ICONSET="$ICON_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC_ICO="$REPO_ROOT/include/images/pgAdmin3.ico"
# sips refuses to upscale an .ico past its largest embedded resolution
# directly; converting it to a plain PNG first works fine as a resize source.
SRC_PNG="$ICON_TMP/source.png"
sips -s format png "$SRC_ICO" --out "$SRC_PNG" >/dev/null 2>&1
for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" \
            "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
	size="${spec%%:*}"
	name="${spec#*:}"
	sips -z "$size" "$size" "$SRC_PNG" --out "$ICONSET/$name.png" >/dev/null 2>&1
done
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICON_TMP"

# Runtime resources. pgAdmin3.cpp's __WXMAC__ branch of LocatePath() sets
# dataDir from wxStandardPaths::GetDataDir(), which on macOS resolves to
# Contents/SharedSupport (NSBundle.sharedSupportPath) -- that's *not*
# Contents/Resources, so these need to land there specifically, or i18nPath
# resolves empty and translations silently fail to load ("nelze otevrit
# soubor '/pgadmin3.lng'"). The .mo catalogs themselves only ever existed as
# prebuilt Windows release assets (x64/Release/i18n/), not something this
# repo's CMake build produces -- there's no source .po/.pot pipeline here at
# all, they're just checked-in binaries alongside the Windows .exe.
if [ -d "$REPO_ROOT/x64/Release/i18n" ]; then
	cp -R "$REPO_ROOT/x64/Release/i18n" "$SHAREDSUPPORT_DIR/i18n"
else
	echo "warning: $REPO_ROOT/x64/Release/i18n not found -- translations won't be bundled" >&2
fi
# Also fixes the "Compare other objects" HTML report template, which looks
# next to the executable first (Windows-only path, since it hardcodes '\\'
# as the separator) and falls back to dataDir -- the mac-only part of that
# fallback already works once dataDir resolves correctly, this just needs
# the file to actually be there.
if [ -f "$REPO_ROOT/x64/Release/textcompare_report.template" ]; then
	cp "$REPO_ROOT/x64/Release/textcompare_report.template" "$SHAREDSUPPORT_DIR/"
fi

# Guru Hint HTML pages + documentation. frmHint::GetPage() builds paths as
# docPath + "/<locale>/hints/<hintPage>.html" where docPath resolves to
# Contents/SharedSupport/docs/ on macOS (see LocatePath() in pgAdmin3.cpp,
# DOC_DIR = "/docs"). The app-docs/ directory at the repo root has the right
# locale/hints/ structure, just under a different name -- copy it over as
# "docs/" so the runtime lookup works.
# Also symlink it into BUILD_DIR for the direct-dev-run path (make run),
# where LocatePath() falls back to loadPath + "/docs" as well.
if [ -d "$REPO_ROOT/app-docs" ]; then
	echo "  -> Copying guru hint docs to bundle SharedSupport/docs ..."
	rm -rf "$SHAREDSUPPORT_DIR/docs"
	cp -R "$REPO_ROOT/app-docs" "$SHAREDSUPPORT_DIR/docs"
	html_count="$(find "$SHAREDSUPPORT_DIR/docs" -name '*.html' | wc -l | tr -d ' ')" || true
	if ls "$SHAREDSUPPORT_DIR/docs/"*/hints/*.html >/dev/null 2>&1; then
		echo "  -> Guru hint docs installed ($html_count HTML files)"
	else
		echo "warning: docs copy may have the wrong structure; 'ls $SHAREDSUPPORT_DIR/docs/'" >&2
		ls "$SHAREDSUPPORT_DIR/docs/" 2>/dev/null || true
	fi
	echo "  -> Creating docs symlink in BUILD_DIR for dev mode ..."
	rm -f "$BUILD_DIR/docs"
	ln -s "$REPO_ROOT/app-docs" "$BUILD_DIR/docs"
else
	echo "warning: $REPO_ROOT/app-docs not found -- guru hints won't be available" >&2
fi

# Info.plist. PGADMIN3_VERSION can be set by the caller (release.sh stamps
# in the date-based release version); otherwise fall back to CMakeLists.txt's
# (rarely-bumped) project version, just so it's never blank.
PGADMIN3_VERSION="${PGADMIN3_VERSION:-$(grep -m1 'project(pgAdmin3 VERSION' "$REPO_ROOT/CMakeLists.txt" | sed -E 's/.*VERSION ([0-9.]+).*/\1/')}"
sed -e "s/@PGADMIN3_VERSION@/${PGADMIN3_VERSION:-0.0.0}/" \
    -e "s/@MACOS_MIN_VERSION@/$MACOS_MIN_VERSION/" \
    "$REPO_ROOT/macos/Info.plist.in" > "$CONTENTS/Info.plist"

# Unsigned binaries need at least an ad-hoc signature to run on Apple Silicon,
# and copying/install_name_tool invalidates whatever signature was there.
codesign --force --deep --sign - "$APP_DIR"

echo "Done: $APP_DIR"
