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

<!-- Append new dated entries below as work progresses. -->
