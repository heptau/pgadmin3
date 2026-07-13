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

- 2026-07-13: More wx-3.3-vs-3.2 API breakage fixed while grinding through the
  build, all real/portable fixes (not mac-only):
  1. `frm/frmStatus.cpp`: many `wxTimerEvent evt;` (default-constructed, used
     only to synchronously call an `OnRefreshXTimer(evt)` handler as a
     "refresh now" trick — none of these handlers call `evt.GetTimer()`).
     wx 3.3 removed `wxTimerEvent`'s default ctor. Fixed by passing the
     contextually relevant `wxTimer&` (e.g. `wxTimerEvent evt(*statusTimer);`)
     at each of the ~13 call sites.
  2. `gqb/gqbGridProjTable.cpp` / `gqb/gqbGridOrderTable.cpp`: sent a
     `wxGRIDTABLE_REQUEST_VIEW_GET_VALUES` grid table message, which wx's own
     header comment says "never did anything, simply don't use them" — wx 3.3
     removed the enum value entirely unless `WXWIN_COMPATIBILITY_3_0` is on.
     Deleted the dead `wxGridTableMessage`/`ProcessTableMessage` call (true
     no-op on every wx version, confirmed no other file relies on it).
  3. `dlg/dlgVariable.cpp`: `wxScopedPtr<wxXmlDocument>` — wx's own header
     says "everything in this file is deprecated, use std::unique_ptr<>
     instead"; swapped it for `std::unique_ptr` (`#include <memory>` added).
  4. `ctl/explainCanvas.cpp` `OnMouseWhell`: called
     `wxScrollHelperBase::HandleOnMouseWheel()` directly, which is a private
     implementation detail in wx 3.3 (was reachable before). Replaced the
     whole body with `ev.Skip()`, which is the documented, portable way to
     let wx's own pushed `wxScrollHelperEvtHandler` apply default wheel
     scrolling (verified in wx's own `src/generic/scrlwing.cpp`).
  5. `ctl/ctlMenuToolbar.cpp` `DoProcessLeftClick`: same `::Node` →
     `compatibility_iterator` swap as before, plus `node == NULL` (ambiguous
     under wx 3.3 since `NULL` isn't a real `nullptr_t` here) → `!node`.
  6. `include/frm/frmLog.h` / `frm/frmLog.cpp` `MywxAuiDefaultTabArt::DrawTab`:
     wx 3.3's `wxAuiFlatTabArt` hides `m_baseColour`/`m_activeColour`/
     `m_borderPen`/`m_baseColourPen` behind a private pimpl (no getters).
     Fixed by overriding `SetColour()`/`SetActiveColour()` in
     `MywxAuiDefaultTabArt` (wx-3.3-gated) to cache the values into our own
     members, then shadowing the old member names with local `const&`
     variables at the top of `DrawTab()` — the ~150-line drawing routine
     below is completely unchanged text-wise.
  7. **A real bug in wxWidgets 3.3.3 itself** (not pgAdmin3, not mac-specific,
     reproducible on any platform): `wx/dynarray.h`'s `wxBaseArray<T>::
     operator[]`/`Item()`/`Last()` return `T&`, but the array is backed by
     `wxVector<T>` (== `std::vector<T>`), and `std::vector<bool>::operator[]`
     returns a proxy object, not `bool&` — so `wxArrayBool` (used by
     `hotdraw/figures/hdIFigure.cpp`'s `selected` member) fails to compile
     with "non-const lvalue reference ... cannot bind to a temporary of type
     reference (aka `__bit_reference<...>`)". Patched the **locally-built
     wx, not pgAdmin3** (`/Users/zv/wx-cocoa-classic/include/wx-3.3/wx/
     dynarray.h`, backup kept as `dynarray.h.orig`) to use the class's own
     `reference`/`const_reference` typedefs instead of raw `T&`/`const T&`.
     Zero impact on the pgAdmin3 repo/upstream merges since it's outside the
     git tree — but **whoever rebuilds wxWidgets from source for this port
     needs to reapply this patch** (or check if a newer wx 3.3.x point
     release has fixed it upstream first).

- 2026-07-13: **It compiles and links.** `cmake --build .` in `build-macos/`
  produces a native `arm64` Mach-O executable (`build-macos/pgAdmin3`, ~13MB).
  Also had to gate the `objcopy --only-keep-debug` POST_BUILD step (GNU
  binutils, ELF-only) behind `if(NOT APPLE)` in `CMakeLists.txt` — macOS has
  no `objcopy`; a `dsymutil`/`strip`-based equivalent could be added later
  but isn't required to get a working binary.
- 2026-07-13: First run attempt: `DYLD_LIBRARY_PATH=/Users/zv/wx-cocoa-classic/lib
  ./pgAdmin3` — the process launches, becomes the active app, and gets a
  real, localized (Czech, from system locale) native menu bar (Soubor,
  Upravit, Plugins, View, Tools, Okno, Nápověda) — confirms the Cocoa/wx
  integration itself works. BUT no window ever appears (confirmed via
  `Quartz.CGWindowListCopyWindowInfo` — zero windows owned by the process).
  Logged error: `nelze otevřít soubor '/pgadmin3.lng'` (can't open
  `/pgadmin3.lng`) — `i18nPath`/`dataDir` (`pgAdmin3.cpp` ~line 1604,
  `stdPaths.GetDataDir()`) is resolving to `/` instead of a real resource
  directory, because this is a bare unbundled executable with no
  `DATA_DIR`/resource layout set up for macOS (the Windows/Linux versions
  expect to be dropped into an existing pgAdmin3 install directory — see
  README). This specific error looks non-fatal (code just skips loading the
  language list if the read fails), so the real blocker for window creation
  is probably a different resource lookup later in `OnInit()` — not yet
  isolated. **Not investigated further this session** — getting a real
  window on screen (and/or proper `.app` bundling with Info.plist/icons/
  resource dirs) is the natural next step, scoped separately from "does it
  compile".

## Known TODOs / not yet solved

- tests/ (Catch2) disabled on macOS in CMakeLists.txt — needs either a
  Catch2 v2 compat shim or porting tests/test_Formatter.cpp to Catch2 v3
  (`catch2/catch_test_macros.hpp` etc).
- No window renders yet at runtime (see status log above) — needs resource
  path plumbing (`dataDir`/`i18nPath`/`DATA_DIR`) sorted out for macOS, most
  likely via a proper `.app` bundle with `Contents/Resources`.
- No `.app` bundle / `Info.plist` / icon / code signing yet — currently just
  a bare executable in `build-macos/`.
- Debug-symbol splitting (dsymutil/strip) skipped on macOS, unlike Windows'
  objcopy-based split — cosmetic, not blocking.

<!-- Append new dated entries below as work progresses. -->
