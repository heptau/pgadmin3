# Thin, OS-aware build helper. See AGENTS.md for the macOS porting story and
# why the paths below look the way they do.
#
#   make          - show this help
#   make build    - configure + build (macOS: also assembles a .app bundle)
#   make run      - run a quick dev build directly (no .app bundling)
#   make release  - macOS only: build, zip (macOS + Windows), tag, GitHub
#                   release, Homebrew tap
#   make build-win - package a portable Windows zip only (any OS, no
#                    compiler needed -- see windows/package_release.sh)
#   make clean    - remove build output

UNAME_S := $(shell uname -s)

WX_COCOA_PREFIX   ?= $(HOME)/wx-cocoa-classic-3.3.4
LIBXML2_PREFIX    ?= /opt/homebrew/opt/libxml2
LIBXSLT_PREFIX    ?= /opt/homebrew/opt/libxslt
POSTGRESQL_PREFIX ?= /opt/homebrew/opt/postgresql@16
BUILD_DIR_MACOS   ?= build-macos
BUILD_DIR_LINUX   ?= build
JOBS              ?= $(shell (command -v nproc >/dev/null 2>&1 && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# --- Docs typography (TypoLima, https://typolima.80.cz) ---
# Language codes for which translated docs exist under docs/<code>/ AND which
# TypoLima itself supports (it has no rules for ja/lv/sr/zh, so those are
# skipped here even though docs/ has them -- keep in sync with both
# lang-switcher.js's language list and `typolima --help`'s --lang list).
DOCS_LANGS = ca cs de en es fr pl ru

PYUSERBASE := $(shell python3 -m site --user-base 2>/dev/null)
TYPOLIMA := $(shell command -v typolima 2>/dev/null)
ifeq ($(strip $(TYPOLIMA)),)
	TYPOLIMA := $(PYUSERBASE)/bin/typolima
endif

.DEFAULT_GOAL := help
.PHONY: help build run release clean pngc docs-typo docs-typo-dry _ensure_typolima build-win

WINDOWS_RELEASE_VERSION ?= $(shell date +%Y.%m.%d)

help:
	@echo "pgAdmin3 build helper (detected OS: $(UNAME_S))"
	@echo ""
	@echo "  make build   - configure + build pgAdmin3$(if $(filter Darwin,$(UNAME_S)), (also assembles a .app bundle),)"
	@echo "  make run     - run a quick dev build directly (no .app bundling)"
ifeq ($(UNAME_S),Darwin)
	@echo "  make release - build, zip (macOS + Windows), tag, GitHub release + Homebrew tap update"
endif
	@echo "  make pngc     - regenerate .pngc embedded-image headers from .png files"
	@echo "  make build-win - package a portable Windows zip from the committed"
	@echo "                   x64/Release/ build (no Windows/compiler needed --"
	@echo "                   see windows/package_release.sh). Override version"
	@echo "                   with WINDOWS_RELEASE_VERSION=... (default: today's date)"
	@echo "  make clean    - remove build output"
	@echo "  make docs-typo-dry - preview TypoLima typography fixes for docs/<lang> ($(DOCS_LANGS))"
	@echo "  make docs-typo     - apply TypoLima typography fixes in-place, same languages"
ifeq ($(UNAME_S),Darwin)
	@echo ""
	@echo "macOS build uses (override any of these as VAR=... make build):"
	@echo "  WX_COCOA_PREFIX   = $(WX_COCOA_PREFIX)"
	@echo "  LIBXML2_PREFIX    = $(LIBXML2_PREFIX)"
	@echo "  LIBXSLT_PREFIX    = $(LIBXSLT_PREFIX)"
	@echo "  POSTGRESQL_PREFIX = $(POSTGRESQL_PREFIX)"
	@echo "See AGENTS.md for how these were set up (wxWidgets needs a local"
	@echo "source build with --disable-std_containers; see AGENTS.md)."
	@echo ""
	@echo "make release requires the 'gh' CLI, authenticated, and a clean"
	@echo "working tree. It versions releases by date (e.g. v2026.07.13) and"
	@echo "promotes CHANGELOG.md's [Unreleased] section automatically --"
	@echo "see macos/publish_release.sh for the full flow."
else ifeq ($(UNAME_S),Linux)
	@echo ""
	@echo "Linux build follows INSTALL.txt / INSTALL_EN.txt (plain cmake + system libs)."
else
	@echo ""
	@echo "make isn't wired up for $(UNAME_S) yet -- see INSTALL.txt / INSTALL_EN.txt,"
	@echo "or the Visual Studio project, for Windows."
endif

pngc:
	bash macos/png2c.sh

build-win:
	./windows/package_release.sh "$(WINDOWS_RELEASE_VERSION)"

ifeq ($(UNAME_S),Darwin)

build:
	cmake -S . -B $(BUILD_DIR_MACOS) -DCMAKE_BUILD_TYPE=Release \
		-DwxWidgets_CONFIG_EXECUTABLE=$(WX_COCOA_PREFIX)/bin/wx-config \
		-DCMAKE_PREFIX_PATH="$(LIBXML2_PREFIX);$(LIBXSLT_PREFIX);$(POSTGRESQL_PREFIX)"
	cmake --build $(BUILD_DIR_MACOS) --config Release -j $(JOBS)
	WX_COCOA_PREFIX="$(WX_COCOA_PREFIX)" ./macos/build_app.sh $(BUILD_DIR_MACOS)
	@echo ""
	@echo "Built: $(BUILD_DIR_MACOS)/pgAdmin III.app -- double-click it, or 'open \"$(BUILD_DIR_MACOS)/pgAdmin III.app\"'"

run:
	WX_COCOA_PREFIX="$(WX_COCOA_PREFIX)" ./run-macos.sh

release:
	@./macos/publish_release.sh

clean:
	rm -rf $(BUILD_DIR_MACOS)

else ifeq ($(UNAME_S),Linux)

build:
	cmake -S . -B $(BUILD_DIR_LINUX) -DCMAKE_BUILD_TYPE=Release
	cmake --build $(BUILD_DIR_LINUX) --config Release -j $(JOBS)

run:
	./$(BUILD_DIR_LINUX)/pgAdmin3

release:
	@echo "make release is macOS-only for now (produces a .app + Homebrew cask)." >&2
	@exit 1

clean:
	rm -rf $(BUILD_DIR_LINUX)

else

build run release clean:
	@echo "make $@ isn't wired up for $(UNAME_S) yet -- see INSTALL.txt / INSTALL_EN.txt, or the Visual Studio project for Windows." >&2
	@exit 1

endif

# --- DOCS TYPOGRAPHY (TypoLima, https://typolima.80.cz) ---
# OS-independent: docs/ is plain HTML, only needs python3/pip.

# Install the TypoLima CLI (pip --user) if it isn't already available, so
# these targets don't require it pre-installed on PATH.
_ensure_typolima:
	@if [ ! -x "$(TYPOLIMA)" ]; then \
		echo "Installing TypoLima CLI..."; \
		pip install --user git+https://github.com/heptau/typolima.git; \
	fi

# Preview typography fixes (smart quotes, non-breaking spaces, dashes, ...)
# for every translated docs/<lang>/ directory without touching any file.
docs-typo-dry: _ensure_typolima
	@for lang in $(DOCS_LANGS); do \
		echo "=== docs/$$lang ($$lang) ==="; \
		$(TYPOLIMA) docs/$$lang --lang $$lang --recursive --dry-run --diff --preserve-format; \
	done

# Apply typography fixes in-place for every translated docs/<lang>/
# directory. Changes land as regular working-tree edits -- review with
# `git diff docs/` before committing.
docs-typo: _ensure_typolima
	@for lang in $(DOCS_LANGS); do \
		echo "-> docs/$$lang ($$lang)"; \
		$(TYPOLIMA) docs/$$lang --lang $$lang --recursive --in-place --preserve-format; \
	done
	@echo "Done. Review changes with: git diff docs/"
