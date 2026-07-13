# AGENTS.md — macOS port notes

Working notes for porting pgAdmin3 (this fork) to build/run natively on macOS
(Apple Silicon, Cocoa backend via wxWidgets). Intended for whichever agent
picks up this work next — treat this as a running log, not final docs.

## Branching strategy (IMPORTANT — read before editing)

- `master` tracks `origin/master` (`git@github.com:levinsv/pgadmin3.git`),
  which is itself a Russian-language fork of the official
  `postgres/pgadmin3`. The user pulls updates from `origin` regularly and
  wants **zero/near-zero merge conflicts**.
- All macOS work happens on the `macos-port` branch. Never commit mac-only
  changes directly to `master`.
- To pick up upstream changes: `git checkout master && git pull origin
  master`, then `git checkout macos-port && git rebase master` (or merge, if
  rebase gets messy).
- When editing shared source files, prefer **additive, ifdef-guarded**
  changes that slot into the existing platform-conditional style already used
  in this codebase (`#ifdef __WXMSW__` / `#ifdef __WXGTK__` / `#ifndef
  __WXMSW__`). Add a new `#ifdef __WXMAC__` / `#ifdef __APPLE__` arm next to
  the existing ones rather than restructuring the conditional. This mirrors
  the existing pattern and keeps diffs small and mergeable.
- Prefer new files (e.g. a macOS CMake overlay) over editing
  `CMakeLists.txt` in place, where possible. If `CMakeLists.txt` must change,
  keep edits additive (new `elseif(APPLE)` branch) rather than touching the
  existing Windows/Linux logic.
- Do not touch `.vcxproj*` files (Windows/Visual Studio only, irrelevant to
  macOS, editing them risks unrelated conflicts).

## Project shape (as of 2026-07-13)

- wxWidgets 3.2+ C++ GUI app (PostgreSQL admin tool), CMake-based build.
- `CMakeLists.txt` already builds cleanly cross-platform via `find_package`
  for wxWidgets/PostgreSQL/libxml2/libxslt — no macOS-specific block exists
  yet (`else()` branch after `if(NOT CROSS_COMPILE)` is generic, currently
  exercised only by Linux CI).
- Zero hits for `__WXMAC__` / `__WXOSX__` / `__APPLE__` anywhere in the
  codebase before this port — this has **never been built on macOS**.
- ~48 files reference `__WXMSW__`, ~48 reference `__WXGTK__` (heavy overlap:
  mostly in `pgAdmin3.cpp`). Many Windows branches have a companion
  `#ifndef __WXMSW__` fallback, which today runs under Linux/GTK and should
  be a reasonable starting point for macOS too (may still need mac-specific
  tweaks for menu bar / keyboard shortcuts / native dialogs — Cocoa quirks
  won't surface until runtime).
- CI (`.github/workflows/*.yml`) only builds on `ubuntu-22.04`, installing
  wxWidgets 3.2 from the codelite PPA equivalent, libxslt/libxml2 via apt,
  postgresql server dev via apt.
- Homebrew has wxwidgets (currently 3.3.3, satisfies the `3.2` minimum),
  libxml2, libxslt, postgresql@16/@17, catch2 — all keg-only or need
  explicit `-D` hints for CMake `find_package` since Homebrew doesn't put
  keg-only libs on default search paths.

## Status log

- 2026-07-13: Branch created, exploring feasibility. No mac-specific code
  written yet. See task list / conversation for live progress; this section
  will be updated as the build gets further.
- 2026-07-13: Correction — there IS a little pre-existing mac scaffolding:
  `include/frm/frmLog.h` has an `#ifdef __WXMAC__` AUI-perspective string, and
  `include/pgAdmin3.h` has an `#ifdef __WXMAC__ void MacOpenFile(...)`. Both
  predate this session; someone attempted a mac port before but it was never
  finished/tested (no CMake path, no other mac ifdefs anywhere).
- 2026-07-13: `cmake` configure works out of the box against Homebrew
  wxwidgets/postgresql@16/libxml2/libxslt with no CMakeLists.txt changes
  needed beyond disabling `add_subdirectory(tests)` on `APPLE` (Homebrew only
  ships Catch2 v3, tests/ use the v2 single-header API — separate, unsolved
  follow-up, tracked as a TODO below).
- 2026-07-13: **Important finding** — Homebrew's `wxwidgets` bottle (3.3.3)
  is built with `wxUSE_STD_CONTAINERS=1` (wx 3.3's new default), which
  changes the shape of `WX_DECLARE_LIST`-generated classes: no more nested
  `::Node` typedef, `GetFirst()`/`GetNext()` etc. return `compatibility_iterator`
  instead of raw `Node*`, and generic `wxList`/`wxNode` (`wxObjectListNode`)
  becomes an incomplete type at the old call sites. This breaks ~262 call
  sites across 18 files (`ogl/*`, `debugger/*`, `frm/mathplot.cpp`,
  `frm/events.cpp`, `ctl/explainCanvas.cpp`, `ctl/explainShape.cpp`, etc.) —
  all legacy code written against the classic (non-std-container) wxList API
  that Windows/Linux builds use today.
  - Patching all 262 sites was rejected: too invasive, spans 18 files shared
    with Windows/Linux, high conflict risk with upstream, for what is really
    a *build configuration* mismatch, not a real portability bug (compare
    to the two genuine bugs below, which WERE worth fixing everywhere).
  - Decision: build wxWidgets 3.3.3 from source locally with
    `--disable-std_containers --with-osx_cocoa`, instead of using the
    Homebrew bottle, to match the classic-mode behavior Windows/Linux already
    rely on. Keeps the pgAdmin3 source tree untouched for this issue.
  - Fixed two small `ctlMenuToolList`/similar cases before discovering the
    scope of the problem — see commits on `macos-port` branch. Those two
    fixes (`ctl/ctlMenuToolbar.cpp`) use `compatibility_iterator`, which is
    portable across BOTH std-container and classic wx builds, so they're
    correct/harmless to keep regardless of which wx we end up using.
- Two genuine, platform-independent bugs found and fixed while getting this
  far (both real bugs that would misbehave/fail to compile on any compiler
  enforcing standard C++, not mac-specific — safe/beneficial upstream too):
  1. `include/ctl/SourceViewDialog.h` (compare-objects HTML report,
     `075347b1` by lsv): mixed `std::wstring + const char*` (narrow literal)
     in an HTML-building expression — fixed by widening the literals to
     `L"..."`.
  2. `include/frm/frmLog.h` / `frm/frmLog.cpp`: `MywxAuiDefaultTabArt`
     (custom AUI tab art) breaks under wx 3.3 because
     `wxAuiDefaultTabArt` became a `#define` alias for the new, non-copyable
     `wxAuiFlatTabArt`, and `GetTabSize()`'s DC parameter type changed from
     `wxDC&` to `wxReadOnlyDC&`. Fixed with a `wxCHECK_VERSION(3,3,0)`-gated
     typedef/Clone(), so wx 3.2 (Windows/Linux) behavior is untouched.

## Known TODOs / not yet solved

- tests/ (Catch2) disabled on macOS in CMakeLists.txt — needs either a
  Catch2 v2 compat shim or porting tests/test_Formatter.cpp to Catch2 v3
  (`catch2/catch_test_macros.hpp` etc).
- Runtime behavior on Cocoa (menus, shortcuts, dialogs, App Bundle
  packaging/.app/.icns/Info.plist) is completely unverified — nothing has
  been run yet, only compiled.

<!-- Append new dated entries below as work progresses. -->
