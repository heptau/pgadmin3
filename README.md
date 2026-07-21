# pgAdmin3 (community fork)

An actively-maintained fork of **pgAdmin III**, the classic native desktop
administration tool for PostgreSQL. The official pgAdmin III project was
retired in favor of the web-based pgAdmin 4, but this fork keeps the native
wxWidgets application alive: fixing bugs against modern PostgreSQL versions
and adding a substantial number of features power users have asked for over
the years (see [CHANGELOG.md](CHANGELOG.md) for the full history).

Upstream (unmaintained) project: <https://github.com/postgres/pgadmin3>

## What this fork adds over stock pgAdmin III

A few highlights out of many — see [CHANGELOG.md](CHANGELOG.md) for the
complete, dated list:

- **Query tool**: auto-select the statement under the cursor, autosave tab
  contents, named/auto-loading bookmarks, multiple result-output windows,
  multi-column result sorting, variable substitution (`$1`, `:name`),
  PCRE-based text transformation dialog, word-hint autocomplete, join
  autocompletion via foreign keys, human-readable big numbers, and a
  "compare 2 cells" diff view.
- **Context help**: hypertext popup help for database objects with
  clickable navigation between functions, tables, and triggers.
- **Server Status / Activity window**: process highlighting, wait-event
  sampling (`pg_wait_sampling`), AWR-style reports, and a CSV log viewer
  with per-column filters and log-line grouping.
- **Schema tooling**: cross-server object comparison with HTML diff
  reports, GitLab-backed schema version control, B-tree index checking via
  `amcheck`, `pgpro_scheduler` job status integration.
- **UI**: SVG toolbar icons, per-server icon coloring, JSON-tree editor for
  the app's own settings file, HiDPI-aware builds.
- **Platform support**: native Windows, Linux, and **macOS** builds
  (Apple Silicon, Cocoa) — see below.
- **Internationalization**: full UI translations in 45 languages,
  all with editable `.po` sources.

## Supported platforms

| Platform | Status | Build |
|---|---|---|
| Windows | Primary target, prebuilt `.exe` in `Release/` | Visual Studio project (`pgAdmin3.vcxproj`) or mingw cross-compile — see [INSTALL_EN.txt](INSTALL_EN.txt) |
| Linux | Actively maintained | `make build` (CMake under the hood) — see [INSTALL_EN.txt](INSTALL_EN.txt) |
| macOS | Stable, community-maintained | `make build` — see below and [AGENTS.md](AGENTS.md) |

Requires PostgreSQL client libraries; the app itself connects to PostgreSQL
12+ and PostgresPro Enterprise, with incremental support added for newer
server versions (13/15/16) as they've been released.

## Building

This repo has a small `Makefile` wrapper around CMake that picks the right
flow for your OS:

```bash
make            # show build help for your detected OS
make build      # configure + build (macOS: also assembles a .app bundle)
make run        # quick dev run (no packaging)
make clean      # remove build output
```

### macOS

Pre-built binary via Homebrew Cask (Apple Silicon, arm64):

```bash
brew install heptau/tap/pgadmin3
```

Or build from source:

```bash
make build
open "build-macos/pgAdmin III.app"
```

The first from-source build needs a locally-built wxWidgets (Homebrew's bottle
isn't compatible out of the box — see [AGENTS.md](AGENTS.md) for why and how
to build one). Once that's in place, `make build` configures CMake, compiles,
and assembles a real double-clickable `.app` bundle with its own icon and
bundled libraries — no `DYLD_LIBRARY_PATH` needed at runtime.

### Linux

```bash
make build
./build/pgAdmin3
```

Needs `wxWidgets` 3.2+, `libxml2`, `libxslt`, and PostgreSQL client/server
dev headers. See [INSTALL_EN.txt](INSTALL_EN.txt) for exact package names
and the mingw cross-compile recipe for producing a Windows build from
Linux.

### Windows

Open `pgAdmin3.vcxproj` in Visual Studio, or cross-compile from Linux with
mingw — see [INSTALL_EN.txt](INSTALL_EN.txt).

## Repository layout

The source tree mirrors pgAdmin III's original module split: `frm/`
(top-level windows), `dlg/` (property dialogs), `ctl/` (custom controls),
`schema/` (database object model), `gqb/` (graphical query builder),
`debugger/` (PL/pgSQL debugger), `pgscript/` (scripting engine), `slony/`
and `agent/` (Slony-I / pgAgent integrations), `ogl`/`hotdraw` (the ERD
canvas toolkit), and `utils/` (shared helpers).

## Contributing / project notes

- [CHANGELOG.md](CHANGELOG.md) — full dated history of changes.
- [AGENTS.md](AGENTS.md) — working notes for the macOS port: how the local
  wxWidgets build is set up, known platform-specific gotchas, and the
  branching approach used to keep macOS-only changes easy to rebase against
  upstream.
- [INSTALL.txt](INSTALL.txt) / [INSTALL_EN.txt](INSTALL_EN.txt) — detailed
  Linux/Windows build instructions (Russian/English).

## License

Released under the [PostgreSQL Licence](LICENSE), same as the original
pgAdmin III project.
