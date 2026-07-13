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

- 2026-07-13: User ran the binary themselves, got a real "pgAdmin III" main
  window (Object Browser, Vlastnosti/Statistics/Dependencies tabs, SQL pane —
  all rendering correctly), but it **crashed** when opening Soubor → Options
  (Ctrl-O). Crash report at
  `~/Library/Logs/DiagnosticReports/pgAdmin3-2026-07-13-143452.ips`:
  `EXC_BAD_ACCESS`/`SIGSEGV` in `wxBitmap::ConvertToImage()`, called via
  `wxBitmapHelpers::Rescale → wxBitmapBundleImplSet::GetBitmap →
  wxGenericTreeCtrl::OnImagesChanged`, from
  `ctlTreeJSON::RefreshImageList() → InitMy() → frmOptions::frmOptions()`.
  First (wrong) theory: `GetBoundingRect()`-derived swatch bitmap size going
  `<= 0` before the tree is laid out. Added a defensive size clamp (kept —
  harmless) but the user reproduced the **exact same crash again** on the
  rebuilt binary, disproving that theory.
  - Since GUI automation couldn't reliably reach the app in this sandboxed
    session (synthetic clicks/keystrokes kept losing focus to the host
    "Claude" desktop app — confirmed via `NSWorkspace.frontmostApplication`),
    switched to a direct repro: added a temporary `PGADMIN3_TEST_OPTIONS=1`
    env-var hook in `pgAdmin3.cpp` right after `winMain->Show()` that
    constructs `frmOptions` directly, bypassing the menu entirely. This
    reproduced the crash reliably and without any GUI-focus guessing.
  - **Real root cause**: `ctlTreeJSON::RefreshImageList()` did
    `wxMask* mask = new wxMask(); bmp.SetMask(mask);` — a *default-constructed*
    `wxMask` has no actual backing bitmap. This makes `wxBitmap::GetMask()`
    return non-null (so wx's `ConvertToImage()` takes the "has a mask" code
    path), but `GetMask()->GetRawAccess()` is null, so the per-pixel masking
    loop dereferences a null pointer. Confirmed by reading
    `src/osx/core/bitmap.cpp`'s `wxBitmap::ConvertToImage()` in our locally
    built wx 3.3.3 source. These swatches are just opaque solid-colour
    rectangles with no real transparency, so the mask was pure dead weight —
    **fixed by deleting the `wxMask`/`SetMask()` calls entirely**.
  - Verified fix: rebuilt, re-ran with the `PGADMIN3_TEST_OPTIONS=1` hook —
    "Nastavení" (Options) dialog opened and rendered completely (Browser/
    Query tool/Miscellaneous tree, all the "Display the following database
    objects" checkboxes, OK/Storno buttons), no crash, no new `.ips` report.
    Removed the temporary test hook afterwards (`pgAdmin3.cpp` is back to
    its pre-hook state) and re-verified a normal launch still shows the main
    window fine.
  - The user should still do one real click-through of Soubor → Options
    themselves to be fully sure, but this is now a well-understood, directly
    reproduced-and-fixed bug rather than a guess.
- 2026-07-13: User confirmed Options no longer crashes, but got a different
  error on quit: `Chyba: nelze otevřít soubor
  '/Users/zv/Library/Preferences/postgresql/pgadmin3opt.json'`. Root cause:
  `pgAdmin3::InitAppPaths()` (`pgAdmin3.cpp` ~line 1088) sets
  `dataDir = GetUserConfigDir() + "/postgresql"` on the non-`__LINUX__`
  branch but — unlike the Linux branch right above it, which does
  `wxMkDir()` if the dir is missing — never creates that directory. Works
  in practice on Windows because it usually already exists from a previous
  install; on a first macOS run `~/Library/Preferences/postgresql/` doesn't
  exist, so both reading and writing `pgadmin3opt.json` (and presumably
  other files under `dataDir`) fail. Fixed by adding the same
  `if (!wxDir::Exists(dataDir)) wxMkDir(...)` guard to the `#else` branch.
  Verified: deleted the directory, relaunched, confirmed it gets created,
  used the app, quit, confirmed `pgadmin3opt.json` (90 bytes) was written
  with no error and no crash report.

- 2026-07-13: Added a top-level `Makefile` (OS-detected via `uname -s`) plus
  `macos/build_app.sh` + `macos/Info.plist.in`, so pgAdmin3 can be launched
  by double-clicking an icon like a normal Mac app, not just run from a
  terminal:
  - `make` (no args) — prints help/usage, including the resolved
    `WX_COCOA_PREFIX`/`LIBXML2_PREFIX`/etc for the current OS.
  - `make build` — configures+builds (macOS: also runs
    `macos/build_app.sh` to assemble a real `build-macos/pgAdmin III.app`);
    Linux path is just the plain cmake flow from INSTALL.txt/INSTALL_EN.txt
    into `build/`; anything else prints a "not wired up" message pointing at
    the existing docs/vcxproj instead of failing silently.
  - `make run` — quick dev run of the bare binary (macOS: delegates to
    `run-macos.sh`, which now reads `WX_COCOA_PREFIX` instead of a
    hardcoded `/Users/zv/...` path so it isn't tied to this one machine).
  - `make clean` — removes the OS-appropriate build dir.
  - `macos/build_app.sh` does the actual bundling: copies the wx/postgres/
    libxml2/etc dylibs the binary depends on into `Contents/Frameworks`,
    rewrites every load command to `@executable_path/../Frameworks/...` (so
    no `DYLD_LIBRARY_PATH` is needed at runtime), generates `AppIcon.icns`
    from the existing `include/images/pgAdmin3.ico` (via `sips`+`iconutil`),
    fills in `macos/Info.plist.in`, and ad-hoc code-signs the bundle
    (`codesign -s -`, required for unsigned binaries to launch on Apple
    Silicon — plain `cp`/`install_name_tool` invalidates the linker's
    original signature).
  - Two real bugs surfaced and got fixed while making the bundle actually
    launch via Finder/`open` (not just from a terminal with
    `DYLD_LIBRARY_PATH` set, which masks these):
    1. **sips can't upscale an `.ico` past its largest embedded
       resolution** (needed 512/1024px icon slots from a 256px source) —
       fixed by converting the `.ico` to a plain PNG first (`sips -s format
       png`) and resizing from that instead.
    2. **Duplicate-library loading crash**: naively copying every `otool -L`
       dependency by its literal path/basename copied both a dylib's real
       versioned file (e.g. `libwx_osx_cocoau_core-3.3.3.0.0.dylib`) *and*
       its symlink aliases (`...-3.3.dylib`, `...-3.3.3.dylib`) as if they
       were different libraries, because different consumers reference the
       library under different symlink names. dyld then loaded the "same"
       library twice under two identities, which showed up as `objc[pid]:
       Class X is implemented in both ...` warnings, `wxIMPLEMENT_DYNAMIC_
       CLASS` RTTI-table-already-registered asserts, and eventually a fatal
       recursive assert inside `wxArtProvider::GetBitmap` while trying to
       show a log dialog (`SIGTRAP`, not the earlier `SIGSEGV` bugs — a new
       and different failure class, easy to mistake for one of those).
       Fixed by canonicalizing every resolved dependency path (following the
       symlink chain by hand, since macOS's `readlink` has no `-f`) before
       deciding whether it's "already bundled", so each real file is only
       ever copied and referenced once regardless of which name pointed to
       it.
  - Verified end-to-end: `make build` from a clean state produces a bundle
    that launches via both `open "build-macos/pgAdmin III.app"` and directly
    executing `Contents/MacOS/pgAdmin3`, with a real "pgAdmin III" Dock/menu-
    bar identity and no `DYLD_LIBRARY_PATH` set, no crash report, no
    duplicate-class warnings.
  - Windows isn't wired into `make` at all (existing build is
    vcxproj/MSVC-based, not shell/make-friendly) — the Makefile just prints
    a pointer to INSTALL.txt / the Visual Studio project for that case.
- 2026-07-13: Added `make release` (macOS only): `macos/publish_release.sh`
  plus two small helpers, `macos/changelog_notes.sh` (extracts one version's
  section body out of CHANGELOG.md — copied near-verbatim from the same
  script in `~/Code/pgarachne`, it's fully generic) and
  `macos/generate_homebrew_cask.sh`.
  - Modeled directly on `~/Code/pgarachne`'s release tooling rather than
    `~/Code/typolima`'s: typolima is a CLI tool distributed as a Homebrew
    **Formula** (installs into `bin/`), but pgAdmin3 (like pgarachne) is a
    GUI `.app`, which needs a Homebrew **Cask** instead — different DSL
    (`cask "pgadmin3" do ... app "pgAdmin III.app" ... end`), different tap
    subdirectory (`Casks/` not `Formula/`). Confirmed by inspecting
    `~/Code/homebrew-tap` (the actual tap repo both projects publish to)
    directly — it already has both a `Casks/` and `Formula/` directory in
    active use by other heptau projects.
  - Since this project doesn't track a real semver, releases are versioned
    by date: `date +%Y.%m.%d` (e.g. `2026.07.13`), tag `v2026.07.13`, with a
    `.2`/`.3`/... suffix appended if a same-day tag already exists locally
    or on the release remote (checked both places).
  - The release script **automatically promotes** CHANGELOG.md's
    `## [Unreleased]` section to `## [<version>]` (inserting a fresh empty
    Unreleased above it) and commits that as part of the release — this was
    a deliberate choice over pgarachne's flow, which requires the maintainer
    to hand-edit CHANGELOG.md before running `make release` and fails if the
    version's heading doesn't already exist. Given `make release` here is
    explicitly invoked to cut a release (not run automatically/on a timer),
    auto-promoting is safe and saves a manual step; every promotion is a
    normal, revertable git commit.
  - Only builds/publishes an **arm64** artifact (no Intel Mac support exists
    yet — the locally-built wxWidgets and this whole port have only ever
    targeted Apple Silicon). The cask has `depends_on arch: :arm64` and no
    `on_intel` block; add one (see `~/Code/pgarachne`'s cask for the pattern)
    if an amd64 build pipeline is ever set up.
  - Release script always pushes to `$RELEASE_REMOTE` (default `origin`,
    i.e. `heptau/pgadmin3`), never `upstream` (`levinsv/pgadmin3`) — matches
    the branching strategy at the top of this file.
  - Homebrew tap update reuses `heptau/homebrew-tap` (same tap typolima and
    pgarachne already publish to) via the GitHub API (`gh api .../contents/
    Casks/pgadmin3.rb`), no local tap clone needed.
  - Verified (without actually releasing — that's a real, public,
    hard-to-reverse action, left for the user to run deliberately): shell
    syntax of all three new scripts (`bash -n`), the Unreleased→versioned
    CHANGELOG promotion logic on a scratch copy of CHANGELOG.md, the
    changelog-notes extraction against the real CHANGELOG.md, and the
    generated cask file's Ruby syntax (`ruby -c`) against a dummy zip.
  - **Not yet exercised end-to-end**: the actual `gh release create` /
    Homebrew-tap-API-push steps, since that requires a real `gh auth login`
    session and would publish for real. First real `make release` run
    should be watched closely.
  - Real-world `make release` run surfaced three more issues, all fixed:
    (1) `gh release create` kept failing with a misleading "'workflow'
    scope may be required" error regardless of token scope, because
    `gh repo view`'s auto-detection picked `upstream` (no write access)
    instead of `origin` when both remotes are configured — fixed by always
    deriving the repo slug directly from `$RELEASE_REMOTE`'s URL, never via
    `gh`'s auto-detection. (2) The resume-detection (see above) only
    checked HEAD's commit message, which broke as soon as any other commit
    landed on top of the "Release vX.Y.Z" commit before a retry (e.g. a
    script bugfix) — fixed to check CHANGELOG.md's actual structure
    (`[Unreleased]` empty + a tag existing for the heading below it) instead,
    and to resume even if the GitHub release for that version already
    exists (only the remaining steps need to run then). (3) **The build
    isn't reproducible** (embedded timestamps / non-deterministic ad-hoc
    codesign output), so re-running `make release` after a release already
    exists and rebuilding would produce a *different* zip than what's
    already uploaded — the freshly-generated Homebrew cask's sha256 then
    didn't match the real downloadable asset, and `brew install` correctly
    rejected it. Fixed by checking whether the GitHub release exists
    *before* deciding to build at all: if it does, skip straight to pulling
    the real sha256 from the already-uploaded asset's `digest` field via
    the GitHub API instead of re-hashing a fresh local rebuild.
- 2026-07-13: User reported the main window's toolbar icons overlapping/too
  close together on macOS, with a request for tooltips. Tooltips were
  already wired up correctly (every `AddTool()` call already passes a
  `shortHelpString`, e.g. `_("Add a connection to a server.")` in
  `pgServer.cpp`'s `addServerFactory` — no code needed there). The overlap
  was real, though: `frmMain::CreateMenus()` (`frm/frmMain.cpp:376`) never
  calls `SetToolBitmapSize()` — the line is literally commented out
  (`git blame`: disabled by lsv on 2023-06-25, the same day as the SVG/HiDPI
  toolbar work per CHANGELOG.md — probably to fix a Windows-side sizing
  issue at the time) — while every menu factory that feeds tools into this
  toolbar (`addServerFactory`/`propertyFactory`/etc. in `pgServer.cpp`,
  `dlgProperty.cpp`, `plugins.cpp`, `frmMaintenance.cpp`,
  `frmEditGrid.cpp`'s view-data factories) requests its icon via
  `GetBundleSVG(..., wxSize(32, 32))`. Without `SetToolBitmapSize` telling
  it that size up front, `wxToolBar` auto-sizes tool cells from whatever it
  sees from the first tool, and on a Retina display the mismatch between
  that auto-derived (too-small) cell size and the actual 32x32-DIP icons
  being drawn produces visibly overlapping buttons. `frmQuery.cpp:612` and
  `frmStatus.cpp:423` already call
  `SetToolBitmapSize(FromDIP(wxSize(32, 32)))` — same pattern, just missing
  from frmMain. Fixed by adding that same call, gated to `#ifdef __WXMAC__`
  only (frm/frmMain.cpp) so as not to touch whatever behavior the maintainer
  was addressing on Windows/Linux in 2023. Verified visually: before/after
  screenshots of the toolbar (icons cleanly separated after the fix).
  Other `ctlMenuToolbar` users (`frmEditGrid`'s own toolbar, `frmConfig`,
  `frmDatabaseDesigner`, `debugger/frmDebugger`) use plain baked-in 16x16
  bitmaps (not `GetBundleSVG`/`wxBitmapBundle`) consistently matched to
  their own `SetToolBitmapSize(wxSize(16, 16))` calls, so they weren't
  affected by this specific bug (though they're not HiDPI/Retina-crisp
  either — a separate, lower-priority cosmetic gap, not reported by the
  user, left alone for now).

## Known TODOs / not yet solved

- tests/ (Catch2) disabled on macOS in CMakeLists.txt — needs either a
  Catch2 v2 compat shim or porting tests/test_Formatter.cpp to Catch2 v3
  (`catch2/catch_test_macros.hpp` etc).
- `.app` bundling is done (`make build`, see status log), but it doesn't put
  any resources into `Contents/Resources` yet beyond the icon — the
  `i18nPath`/translations lookup (`.lng` file, "nelze otevřít soubor
  '/pgadmin3.lng'") still isn't solved and is harmless/non-fatal so far, but
  should eventually get real resource files bundled and `i18nPath` pointed
  at `Contents/Resources` instead.
- App icon is upscaled from a single 256x256 source (`include/images/
  pgAdmin3.ico`) — looks fine at normal Dock size but real multi-resolution
  artwork would look sharper at 512/1024.
- Not code-signed with a real Developer ID (ad-hoc only) or notarized —
  fine for running on this machine, but Gatekeeper will complain
  ("unidentified developer") if the `.app` is copied to another Mac; the
  user would need to right-click → Open the first time there.
- Debug-symbol splitting (dsymutil/strip) skipped on macOS, unlike Windows'
  objcopy-based split — cosmetic, not blocking.

<!-- Append new dated entries below as work progresses. -->
