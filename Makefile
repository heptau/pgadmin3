# Thin, OS-aware build helper. See AGENTS.md for the macOS porting story and
# why the paths below look the way they do.
#
#   make          - show this help
#   make build    - configure + build (macOS: also assembles a .app bundle)
#   make run      - run a quick dev build directly (no .app bundling)
#   make clean    - remove build output

UNAME_S := $(shell uname -s)

WX_COCOA_PREFIX   ?= $(HOME)/wx-cocoa-classic
LIBXML2_PREFIX    ?= /opt/homebrew/opt/libxml2
LIBXSLT_PREFIX    ?= /opt/homebrew/opt/libxslt
POSTGRESQL_PREFIX ?= /opt/homebrew/opt/postgresql@16
BUILD_DIR_MACOS   ?= build-macos
BUILD_DIR_LINUX   ?= build
JOBS              ?= $(shell (command -v nproc >/dev/null 2>&1 && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.DEFAULT_GOAL := help
.PHONY: help build run clean

help:
	@echo "pgAdmin3 build helper (detected OS: $(UNAME_S))"
	@echo ""
	@echo "  make build   - configure + build pgAdmin3$(if $(filter Darwin,$(UNAME_S)), (also assembles a .app bundle),)"
	@echo "  make run     - run a quick dev build directly (no .app bundling)"
	@echo "  make clean   - remove build output"
ifeq ($(UNAME_S),Darwin)
	@echo ""
	@echo "macOS build uses (override any of these as VAR=... make build):"
	@echo "  WX_COCOA_PREFIX   = $(WX_COCOA_PREFIX)"
	@echo "  LIBXML2_PREFIX    = $(LIBXML2_PREFIX)"
	@echo "  LIBXSLT_PREFIX    = $(LIBXSLT_PREFIX)"
	@echo "  POSTGRESQL_PREFIX = $(POSTGRESQL_PREFIX)"
	@echo "See AGENTS.md for how these were set up (wxWidgets needs a local"
	@echo "source build with --disable-std_containers; see AGENTS.md)."
else ifeq ($(UNAME_S),Linux)
	@echo ""
	@echo "Linux build follows INSTALL.txt / INSTALL_EN.txt (plain cmake + system libs)."
else
	@echo ""
	@echo "make isn't wired up for $(UNAME_S) yet -- see INSTALL.txt / INSTALL_EN.txt,"
	@echo "or the Visual Studio project, for Windows."
endif

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

clean:
	rm -rf $(BUILD_DIR_MACOS)

else ifeq ($(UNAME_S),Linux)

build:
	cmake -S . -B $(BUILD_DIR_LINUX) -DCMAKE_BUILD_TYPE=Release
	cmake --build $(BUILD_DIR_LINUX) --config Release -j $(JOBS)

run:
	./$(BUILD_DIR_LINUX)/pgAdmin3

clean:
	rm -rf $(BUILD_DIR_LINUX)

else

build run clean:
	@echo "make $@ isn't wired up for $(UNAME_S) yet -- see INSTALL.txt / INSTALL_EN.txt, or the Visual Studio project for Windows." >&2
	@exit 1

endif
