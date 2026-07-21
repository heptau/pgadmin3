# Changelog

All notable changes to this pgAdmin3 fork are documented in this file.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Completed all 45 shipped languages — every `.mo` catalog was recovered as
  an editable `.po` source, merged against the current POT, and all missing
  UI translations filled in (human translation for cs_CZ, es_ES, de_DE, fr_FR;
  Google Translate for the remaining languages). All languages build with 0
  untranslated entries and pass `msgfmt -c`.

### Fixed
- Fixed broken `.mo` files for 11 languages that had header malformations or
  format-specifier mismatches: zh_CN, de_DE, ja_JP, fa_IR, ko_KR, pl_PL,
  zh_TW, af_ZA, sr_RS, lv_LV, ru_RU. All now compile cleanly.

## [2026.07.14]

### Added
- Added `.po` source files for all 7 remaining shipped languages (ru_RU,
  pl_PL, ja_JP, zh_CN, sr_RS, ca_ES, lv_LV) — previously only compiled
  `.mo` files existed, with no editable source or build pipeline.
- Filled in missing UI translations for zh_CN (~189 new strings), lv_LV
  (~112), ru_RU (~189), and pl_PL (~189). The existing `.mo` catalogs for
  ca_ES, sr_RS, and ja_JP were recompiled from the merged `.po` baseline
  with no new translations added (task-agent results for those languages
  were lost mid-session).
- Added a bilingual (Czech/English) project website at `docs/index.html`
  with language toggle, dark/light theme switch, and screenshot.
- Added `macos/png2c.sh` — regenerates all `include/images/*.pngc`
  embedded-image headers from the corresponding `.png` sources.
- Added `make pngc` target to the top-level `Makefile`.
- Added Homebrew Cask install instructions to `README.md`
  (`brew install heptau/tap/pgadmin3`).
- Filled in ~406 missing French (fr_FR) UI translations, same gap and
  method as Spanish/Czech. Added `i18n/fr_FR.po` and recompiled
  `x64/Release/i18n/fr_FR/pgadmin3.mo`. With this, all four requested
  languages (cs_CZ, es_ES, de_DE, fr_FR) have had their translation gaps
  filled.
- Filled in ~920 missing German (de_DE) UI translations — this catalog
  had a substantially larger gap than the others (missing much of the
  Database Designer and pgAgent job scheduler coverage). Added
  `i18n/de_DE.po` and recompiled `x64/Release/i18n/de_DE/pgadmin3.mo`.
- Filled in ~406 missing Spanish (es_ES) UI translations, same gap and
  method as the Czech pass. Added `i18n/es_ES.po` as the editable source
  of truth and recompiled `x64/Release/i18n/es_ES/pgadmin3.mo`.
- Filled in ~406 missing Czech (cs_CZ) UI translations that were never
  covered by the shipped 2014 catalog (newer features like logical
  replication publications/subscriptions, the query tool's autoreplace/
  align/format commands, the database designer/ER-diagram tool, pg_wait_
  sampling status view, etc). Added `i18n/cs_CZ.po` as the new editable
  source of truth for this catalog (previously only a compiled `.mo` was
  checked in, with no `.po`/build pipeline at all) and recompiled
  `x64/Release/i18n/cs_CZ/pgadmin3.mo` from it.

### Fixed
- Fixed translations (localization catalogs) never loading on macOS —
  `wxStandardPaths::GetDataDir()` resolves to `Contents/SharedSupport` on
  macOS (not `Contents/Resources`), which the `.app` bundle never
  populated, so `i18nPath` resolved empty and the UI silently fell back
  to untranslated (English) strings. `macos/build_app.sh` now copies
  `x64/Release/i18n` (the prebuilt `.mo` catalogs, checked in as Windows
  release assets) into `Contents/SharedSupport/i18n`, and also copies
  `textcompare_report.template` there for the same reason.
- Fixed the main window's toolbar icons overlapping on macOS (Retina
  displays specifically) — the toolbar's bitmap size was never set to
  match the 32x32 icons being drawn into it.
- Fixed `make release` producing a Homebrew cask whose checksum didn't
  match the actual uploaded release asset when re-run after a release
  already existed (the local build isn't byte-for-byte reproducible
  between runs).
- Fixed several light/dark mode (macOS) appearance bugs: some Object
  browser tree items showing a stuck, wrong background colour; the SQL
  panel not repainting at all when switching system appearance while the
  app was running; and some SQL syntax-highlighting colours staying
  black (unreadable) in dark mode.

### Changed
- Regenerated all `include/images/*.pngc` embedded-image headers from the
  corresponding `.png` sources via `make pngc` (smaller file sizes,
  consistent format).

## [2026.07.13]

### Added
- Native macOS build support: an OS-detecting top-level `Makefile`
  (`make build` / `make run` / `make clean`) and `macos/build_app.sh`, which
  assembles a real double-clickable `pgAdmin III.app` — bundled dependencies,
  a generated app icon, and ad-hoc code signing, with no `DYLD_LIBRARY_PATH`
  or machine-specific paths needed at runtime.
- `run-macos.sh` convenience launcher for a quick dev run without full `.app`
  bundling.
- `AGENTS.md`, documenting the macOS wxWidgets build setup and porting
  decisions for future contributors.

### Fixed
- Fixed a crash opening the Options dialog on macOS, caused by an
  uninitialized `wxMask` attached to the object-tree color swatches
  (`ctlTreeJSON::RefreshImageList`).
- Fixed missing creation of the settings data directory on macOS/Windows on
  first run (previously only handled on Linux), which could prevent reading
  or writing `pgadmin3opt.json`.
- Fixed several wxWidgets 3.3 compatibility issues encountered while adding
  macOS support (mixed wide/narrow string literals in the HTML diff-report
  generator, `wxTimerEvent` construction, deprecated `wxScopedPtr` usage,
  custom AUI tab-art color handling, and a couple of dead/no-op API calls) —
  see `AGENTS.md` for details; these were guarded so the Windows/Linux build
  path is unaffected.

## [2026-06-30]

### Added
- Added the query start time to the History tab.

### Fixed
- Fixed "Execute to file".

## [2026-06-25]

### Fixed
- When building a plan with analysis, trigger execution time is now calculated as a percentage of total execution time.

## [2026-06-23]

### Fixed
- Fixed incorrect error position reporting.

## [2026-06-22]

### Added
- The "copy result" function is now always enabled in the context menu.

## [2026-06-19]

### Added
- Added the ability to move between open servers.

### Fixed
- Disabled writing of empty SchemaRestruction entries to the config.
- Fixed copying diff output to HTML.

## [2026-06-17]

### Added
- Added an option to disable certificate verification for the GitLab site.

## [2026-06-16]

### Added
- The comparison dialog's parameters are now saved between sessions.

## [2026-06-15]

### Added
- Added a "DiffText" button to the query tool.

### Fixed
- When deleting objects in the browser, the browser's focus is now checked first.

## [2026-06-11]

### Added
- Added the ability to download a Git repository archive.
- Space substitution is now accounted for when converting content to HTML.
- Disabled the flicker-reduction optimization on Linux.

### Fixed
- Fixed compilation with Microsoft Visual Studio.

## [2026-06-08]

### Fixed
- Fixed the AWR report.

## [2026-06-05]

### Fixed
- Fixed the compare dialog.

## [2026-06-03]

### Fixed
- Optimized the Linux build/compile process.

## [2026-05-27]

### Added
- The function editing dialog now shows a comparison between the original and modified function text.

### Fixed
- Fixed word-mode diffing in diff_match_patch.

## [2026-05-26]

### Added
- The entire text in the context help window can now be selected by pressing "a".
- Improved the two-cell comparison dialog.

## [2026-05-25]

### Added
- Added a comparison option to the two-cell comparison dialog.

### Fixed
- Disabled ellipsizing on wxGTK.

## [2026-05-07]

### Added
- Added the ability to copy a bookmark selection.

### Fixed
- Fixed the mingw build.

## [2026-04-30]

### Fixed
- Fixed the compare report.

## [2026-04-24]

### Added
- Added a "Set keywords" menu item for defining server search keywords.
- Added server-related commands to the Server submenu.

## [2026-04-22]

### Added
- Added a keywords parameter for servers, used to locate a server by pressing F4.

## [2026-04-20]

### Added
- Added SVG toolbar icons.

### Fixed
- Fixed parsing of the plugins.ini file.
- The connection-selection dialog now restores the selected group.
- Fixed clipboard handling on Linux.

## [2026-04-17]

### Fixed
- Fixed the default view size for the query tool.

## [2026-04-16]

### Added
- The query tool toolbar now uses 32x32 SVG icons.

### Fixed
- Fixed the position of the plugins menu.

## [2026-04-13]

### Added
- Added Wayland support.
- Added PuTTY support on Windows.
- Added hotkey support for the context help window.

### Fixed
- Fixed a GTK-related bug.

## [2026-03-27]

### Fixed
- Fixed a crash.
- Fixed the displayed scale_factor value.

## [2026-03-26]

### Added
- Added a full view of server groups to the connection selection dialog.

## [2026-03-18]

### Added
- Added server groups to the connection selection dialog.

### Fixed
- Fixed a Clang compiler warning.
- Minor Linux build/debugging fixes.

## [2026-03-17]

### Added
- Added automatic execution of the PuTTY-forward plugin on Linux.

## [2026-03-04]

### Added
- Added single-quote support for HTML preview.
- Context help screenshots can now be copied by pressing "s".

### Fixed
- Fixed AutoSelectQuery behavior.
- Fixed assertion failures in the context help screenshot feature.

## [2026-03-03]

### Added
- The context help window can now be zoomed in by pressing "+".
- Added help for pgadmin3opt options, accessible via Ctrl+F1.

## [2026-03-02]

### Fixed
- Fixed a bug in the Log window (frmLog).

## [2026-02-27]

### Added
- Added a Ctrl+F1 hotkey for JSON options.
- Query result integers can now be viewed in a human-readable form.

### Fixed
- Added an error message for a previously silent failure case.

## [2026-02-25]

### Added
- Query results can now display thousands separators for integer values.
- Added a Ctrl+W hotkey to disconnect from the database.

## [2026-02-20]

### Fixed
- Removed localization of `application_name`.

## [2026-02-18]

### Added
- Added context help for the generation feature.
- Server Status window database operations now run on a separate thread, improving UI responsiveness.

### Fixed
- Fixed flickering in the Activity window on Linux.
- Fixed an application crash.

## [2026-02-17]

### Fixed
- Fixed the Compare Database feature on Linux.
- Fixed a performance issue when setting/clearing filters.
- Fixed a performance issue in code generation and added context help for it.

## [2026-02-06]

### Added
- Added a Log window command to enable/disable the auto hint.

## [2026-02-04]

### Added
- The selected server item is now saved and restored.

## [2026-01-30]

### Added
- Added support for using PuTTY for SSH tunnels.

### Fixed
- Fixed the log file listing in the Log window (frmLog).

## [2026-01-27]

### Changed
- Removed the context menu from the "Log File" window; right-clicking now opens the row preview directly.

## [2026-01-21]

### Added
- Added a hotkey to trigger code generation, along with minor related fixes.

## [2026-01-16]

### Added
- Template parsing error messages are now shown in the status bar.
- Added a new flag for code generation.

### Fixed
- Fixed copying of 3-byte characters into HTML.

## [2026-01-14]

### Fixed
- Fixed generation of the INSERT SQL statement.
- Fixed copying of result rows based on a template.

## [2026-01-13]

### Fixed
- Fixed GUI issues on Linux.

## [2025-12-30]

### Added
- Added a view of foreign tables to the contextual help.

## [2025-12-29]

### Fixed
- Fixed an application crash.

## [2025-12-26]

### Fixed
- Fixed the cross-compile build.

## [2025-12-25]

### Changed
- On Linux, the application's data path was changed to `XDG_DATA_HOME`.

## [2025-12-24]

### Added
- Limited the coloring of hints in query results.
- Query results are now underlined in red when they have been truncated due to the maximum column size setting.

## [2025-12-12]

### Changed
- Changed the copy method used in the context help window.

## [2025-12-09]

### Fixed
- Fixed a visual/rendering optimization issue on Linux.

## [2025-12-08]

### Added
- The "autovacuum launcher" process is now highlighted when inactive replication slots are present.

### Fixed
- Fixed label colors in the "Top Activity" view.

## [2025-12-03]

### Added
- Added navigation keys (keyboard navigation) to the context help window.

## [2025-12-02]

### Fixed
- Fixed a lost semicolon (";") during SQL formatting.

## [2025-11-28]

### Added
- Added a `quote_ident` function.
- Added MinGW build support.
- Added anchors to the function help pages.

## [2025-11-21]

- Contextual help for functions has grown into hypertext navigation across functions, tables, and triggers.
  The selected expression is checked against database object names, and if a match is found, the creation
  script is shown as the object's help/reference. The script is analyzed for function calls and table/view
  names, which are replaced with links. The analysis is not exact, so incorrect links are possible.
  Navigate back with the right mouse button.
- Added a directory for tests, but they will only work when compiled on Linux.

## [2025-08-06]

- The context help popup is now also used as a tooltip for displaying log lines.
  Likewise, in query results, right-clicking now invokes it with the cell's content.
  The popup window's appearance is stored in the json file, in the `PreviewOptions` section.
- Server Status window
  - In the "log file" window you can now see full-size log lines in a tooltip.
    Selected text in the tooltip popup, when right-clicked, is used as the search string.
  - Fixed the query that retrieves server information; it now runs faster.
    Added information about query execution time to the status bar.

## [2025-07-31]

### Added
- In query results, right-clicking now opens a preview/hint window that lets you select and copy its
  contents (via the right mouse button).

### Fixed
- When auto-completing table join conditions, the PK is now used for self-joins of a table.

## [2025-03-25]

### Added
- Added the `-el` key to export server information into the settings file of the Linux version of pgadmin3.
- Changes to the graphical query plan display:
  - Added images for two plan nodes: Partial GroupAggregate, Finalize GroupAggregate.
  - The Memoize node is now drawn dynamically with a percentage bar of cache Hits, and indication of
    Evictions and Overflows.
  - Added mouse wheel support.
  - If the plan has more than 300 nodes, a rendering optimization kicks in (may cause visual artifacts
    when scrolling).

### Fixed
- Fixes for the Linux version:
  - In the "Status Server" window, reduced flickering when updating active process rows.
    A dummy row was added at the end of the process list when a filter is in use.
  - Added a check in ctlSQLGrid for matching grid and row-header colors.

## [2025-02-10]

### Added
- Extended autocomplete capabilities. Added suggestion of table (and view) joins based on their FK.
  - Autocomplete works in two modes:
    - After the `ON` keyword: the rightmost table is joined to any table on the left.
    - After the keywords `WHERE`/`AND`/`OR`: all tables are joined with all tables.
  - The join condition is completed after the `=` sign.
    Views can only be joined if the view's field is a field of the underlying table.
    Suggestion works correctly when table aliases are used.

### Fixed
- Standard autocomplete now offers a list of tables and views after `JOIN`.

## [2024-12-17]

### Added
- Added quick substitution of Latin-alphabet words on pressing Alt+RIGHT. Enabled via the
  "Use word hints" setting. The word list is built when a query is loaded and as new words are typed.
- When executing a query, added the ability to replace variables of the form `$1`, `$2`, ... or
  `:variableName` with user-supplied values entered in a dialog. Currently works for select, update,
  delete, and insert queries. Variables are substituted with plain text replacement before the query
  is sent to the server. The query that was actually executed on the server can be viewed in the History
  tab. Enabled via the "Replace variables in a query" setting. Selecting the executed query with the right
  mouse button will not work as expected, since the executed query text differs from the text in the
  editor. Replacement values are saved to `pgadmin3opt.json` (on program exit).

## [2024-09-24]

### Added
- Windows build now uses the stdcpp17 setting.
- Added a text transformation dialog to the query editor using PCRE expressions, with syntax highlighting
  and highlighting of matched groups. Invoked with Ctrl+M. Dialog settings are saved in `pgadmin3opt.json`.
  Wiki article: [Transformation text](https://github.com/levinsv/pgadmin3/wiki/Transformation-text).
- Added an item to the settings dialog for editing `pgadmin3opt.json`. The json settings are presented as
  a tree. Insert adds/copies an element in an array. Delete removes it. Ctrl+Z undoes changes (but not
  insert/delete). Ctrl+F searches for a string.
- In the "Status Server" window, a navigation panel with color indicators now appears while logs are
  loading. Configuration and available commands are in a json file. Several colored indicators are
  included as examples. Command help is available via F1. Works only with CSV logs.
- In the "Status Server" window, added the ability to enable collection of process wait events. Requires
  the `pg_wait_sampling` extension to be installed. The `ClientRead` wait is only collected while a
  transaction is open and has been assigned an identifier — i.e., it reflects waiting for client data only
  during an active transaction. Wiki article: [Waits events](https://github.com/levinsv/pgadmin3/wiki/Waits-events).

## [2023-10-27]

### Fixed
- You can now specify additional connection parameters —
  [commit 0093e3676c480cd6886a66feb10cb26d99a2e315](https://github.com/levinsv/pgadmin3/commit/0093e3676c480cd6886a66feb10cb26d99a2e315).
- Added the ability to enable/disable autosaving of queries and quick navigation to root nodes of the
  object tree — details in
  [commit bce303c437944ab4ad13bcc7303dbe644a92618a](https://github.com/levinsv/pgadmin3/commit/bce303c437944ab4ad13bcc7303dbe644a92618a).
- Generation of an AWR report when the `pgpro_pwr` extension is installed —
  [commit c139994efa9bdafd235e3d620fe4ed05946f7330](https://github.com/levinsv/pgadmin3/commit/c139994efa9bdafd235e3d620fe4ed05946f7330).

## [2023-08-05]

### Fixed
- A more readable display of large numbers on the Statistics page can now be enabled. To do this, set
  the "Beautiful big numbers on the statistics page" checkbox.

## [2023-08-02]

### Added
- Added the ability to hide/show the query history panel.
- Added some PG16 capabilities:
  - Display of the new role-membership options SET and INHERIT (cannot be set from the dialogs).

### Fixed
- Fixed an infinite loop when executing pgScript (wxRegEx handling rules changed).
- Fixed GDI object leaks.

## [2023-06-29]

pgAdmin3.exe is now built with the new wxWidgets 3.2 for improved DPI handling. Update your wx\*.dll
files. The executable is compiled with a manifest declaring DPI-awareness support.

You can now replace the PNG icons in the toolbar with SVG icons. To do this, create an `svg` directory
next to the executable and place files with the `.svg` extension in it. The file name must match the
name of the original PNG file from the `include/images` directory. Currently the icons of the main
window, the query window, and the server status window can be replaced. File names can be found in the
source code by searching for the string `*GetBundleSvg`.

On first launch, pgAdmin3.exe may crash. Before the first launch, save a backup copy of the
`autoSaveConfig.reg` file. If needed, other icons can also be converted to SVG.

Performance optimizations were made for object tree refresh and query result display.

## [2023-06-06]

If a search in the object tree starts from a server node, the search continues only among servers,
without descending into their contents.

## [2023-05-22]

To improve visibility and make it clearer which database you are working with, when an item is selected
in the object browser, the database name is now displayed next to it in the status line. This behavior
can be disabled in the settings.

## [2023-05-02]

Added the ability to align lists of insert commands and other structured data (IN lists). In the
settings you can specify an external utility that takes the selected text as input and returns it
aligned on output. If no utility is specified, alignment will be performed by pgadmin3 itself (the code
has not been fully tested and hangs are possible). Full description in
[commit c197ea45c18385204497a1f53f1fda184c6cc86b](https://github.com/levinsv/pgadmin3/commit/c197ea45c18385204497a1f53f1fda184c6cc86b).

## [2022-11-24]

Added an experimental feature for working with GitLab. To use it with GitLab, place a `gitlab.json` file
in the `%APPDATA%\postgresql` directory. Example file contents:

```json
{
"url": "https://gl.mympany.ru:4443/api/v4/",
"private_token": "V3JYpw2x5rr61yGe_M2e",
"project_id": "532"
}
```

After starting pgAdmin3, a "Git" tab will appear containing additional tabs. For now, the only
supported GitLab operation is committing, from the additional "Commit" tab. Only the contents of schema
objects are saved to GitLab — only the SQL representation is stored.

The workflow is as follows:

- Connection information for GitLab is taken from the `gitlab.json` file.
- The `pgadmin3.json` file with general settings is read from the default branch (usually `main`).
- If that file does not exist, settings are taken from `gitlab.json`.
- Example settings from `pgadmin3.json`:

```json
{
"ignore_schema": ["public","repack","schedule"],
"control_objects": ["Functions","Views","Tables","Trigger Functions","Procedures","Schemas","Schema","Database"],
"maps_branch_to_dbname":[
	{"branch": "asu",
         "list_db": ["asu"]
        }
        ,
       	{"branch": "common_db",
         "list_db": ["dbname1","dbname2"]
        }

]
}
```

Where:
- `ignore_schema` — list of schemas that should not be saved to git.
- `control_objects` — list of schema object types that should be saved.
- `maps_branch_to_dbname` — mapping of branch names to database names.

- Clicking the "Load Git" button loads the SQL representation of objects from GitLab.
  After this operation, the "List commit files" list is populated with the differences between the
  current database and the GitLab branch.
- If you select several items (or all of them with Ctrl+A), enter a commit message, and click the
  "commit" button, the current SQL representation of the selected items will be committed to GitLab.
- Right-clicking any item in the list shows the differences between the object in the database and in
  GitLab.

All other buttons and tabs should not be used. The typical use case is keeping a history of changes to
database objects in GitLab.

## [2022-07-06]

Added partial support for PG15 features:

### Added
- Support for a column list when defining an FK.
- Support for NULLS NOT DISTINCT for unique indexes.

## [2022-01-13]

### Added
- Added to Log view: support for quick navigation: Shift+KeyUP, KeyDOWN moves to a record with the same
  `sql_state`; Alt+KeyUP, KeyDOWN moves to a record with a different `sql_state`. Added a "Server"
  column showing which server the log entry was received from.
- Added saveable user-defined filters in frmLog. Clicking "Add" saves the current filter; its name is
  set in the ComboBox.

### Fixed
- Ctrl+S now sends the message by Outlook mail. The email template is in the `mail.template` file. The
  first two lines of the template can specify addresses to be inserted into the message.
- In the "Status Server" window, the parameters `SET statement_timeout=10000;` and
  `SET log_min_messages = FATAL` are now set to avoid the `pg_query_state` function hanging.
- When the error "server closed the connection unexpectedly" occurs, the message is no longer displayed
  on screen, since it used to cause pgAdmin3 to crash.

## [2021-09-13]

### Added
- Added a menu command to close all open servers, "Disconnect all servers".

## [2021-08-19]

Added a window for viewing the database's CSV log. The window is opened from the server's context menu,
"Log view ...".

After the window is opened, the log file is read directly using the `pg_read_binary_file` function. The
file with the most recent modification date is selected. Checking for new messages happens every 5
seconds. Other servers can be added on the "Settings" panel; settings take effect after the window is
closed and reopened. If the log window is not the active window and a message of level Error or higher
arrives, its icon is marked with a red square. If several servers are selected on the "Settings" tab,
they are connected to automatically. After connecting, all open servers in the object tree can be closed
with a single context-menu command, "Disconnect all servers".

WARNING: the memory required to store logs is not limited in any way (aside from filtering applied at
log-loading time), so large amounts of memory may be allocated.

Log lines are displayed in two modes:

- Simple. All received log lines are displayed.
- Group. Lines with similar messages are merged into a group, and the visible row is the most recent
  line in the group. To view all lines of a group, set the "View detail group" flag. Messages are
  considered similar if they differ only in numbers and are not inside double quotes. In group mode, the
  host field shows a counter of new messages that fell into the group. The counter resets when the
  cursor is placed on the group's row.

Per-column filters are used to exclude unwanted lines from the view. To enable a filter:

- Right-click the field. Hold Ctrl to invert the filter.
- Select a value from the column header's context menu. It shows the 20 most frequent values in the
  column along with their counts.
- Enter a value in the field, select that value, and press Enter. Only the selected text is used for the
  filter. Such a filter searches for the selected substring within the field. If the first character of
  the selected text is "!", the filter is inverted.
- Each individual filter value can be removed via the column header's context menu.

For better performance it is recommended to load logs with "Mode group" enabled, or to disable "Mode
group" only while filters are set. Displaying a large number of rows (more than 10000) can take several
seconds or more.

You can also discard lines at load time. To do this, set filters on the rows and click "Add Filter
Ignore" — this filter will be written to the `filter_load.txt` file.

## [2021-02-19]

### Added
- Window layout is now preserved when the outputPane is hidden, and reapplied when it is shown again.
- It is now possible to change the icon of the query window. There are two ways to change the icon for a
  query window:
  1. Place a new icon in `%APPDATA%\postgresql\icons`. Name the file as follows:
     `hostname_dbname.png`, or `hostname.png`, or `dbname.png`. Icon size 32x32.
  2. Assign a color to the server. The icon's background will be colored with the server's color.

## [2021-01-03]

### Added
- Compiled a 64-bit version of pgAdmin3.exe.
- The 32-bit version is no longer supported.

## [2021-01-02]

### Added
- Added sorting on the "Properties", "Statistics", and other tabs.
- For partitioned tables, statistics now show all descendant partitions.

## [2020-12-05]

### Added
- Added btree index verification. The check is performed by the `bt_index_parent_check(regclass,true)`
  function from the `amcheck` extension. The extension must be installed in the database that pgadmin3
  connects to.

### Fixed
- Many small fixes.
- Added support for some new PG13 features. See the commits for details.

## [2020-09-05]

### Added
- Added the ability to exclude privileges and comments from comparison when comparing objects.

### Fixed
- Fixed copying of query text from under the filter in the Server status window. When comparing text
  from the Client column, the port is now ignored.

## [2020-09-02]

### Added
- Added the ability to copy selected query result cells to the clipboard formatted as an IN list or a
  WHERE clause. Invoked from the context menu.
- In the Server status window, added the ability to filter rows via right-click.

### Fixed
- Fixed issue #8 (dropping overloaded procedures).

## [2020-05-08]

### Fixed
- Fixed issue #6 (Child tables are not displayed). Displaying partitions from other schemas breaks
  strict object hierarchy, and you should make sure everything looks correct in your case. Partitions
  are always grouped under a "Partitions" node located in the parent table. In its native schema, a
  partition cannot be seen as a regular table.
- Minor improvements.

## [2020-05-06]

### Fixed
- Fixed issue #4 (Crash after close sql editor).

## [2020-04-22]

### Added
- Added the ability to create additional windows for displaying query results (up to 9). To do this, run
  the query with Shift+F8. Running with F8 sends results to the currently active tab. Result windows are
  marked with a white square if they have been used by the current query tab.
- Right-clicking the active results tab in the query window now selects the query associated with that
  result.
- In the query window, the most recently executed query is marked with green arrows.
- When autosaving query tabs, the cursor position is now saved as well.

## [2020-04-15]

### Fixed
- The table-creation SQL statement window now shows the new storage parameters.
- Column descriptions now account for generated and identity columns.

## [2020-04-13]

### Fixed
- Fixed a crash in edit mode.
- Fixed editing of procedures without arguments.

## [2020-04-11]

### Added
- Added multi-column sorting of query results. Column sort order and direction are marked with colored
  indicators (RED, YELLOW, GREEN, BLUE, GREY). Maximum number of sort columns is 5. To sort, click a
  column header while holding Alt.
- Added new options for Vacuum (DISABLE_PAGE_SKIPPING) and Reindex (CONCURRENTLY).

### Fixed
- Sped up the filter in the query results window.

## [2020-03-28]

### Added
- Added information about table fragmentation (cfs_fragmentation).

### Fixed
- Removed the server version warning.

## [2020-03-04]

### Added
- Added output of CREATE STATISTICS for tables.

### Fixed
- Fixed the SQL command output for creating a job for commands specified as an array.

## [2019-12-22]

### Added
- Added the ability to compare object descriptions between different servers, via the Reports menu →
  "Compare other objects". The comparison is performed against another open connection and connected
  database. Objects to compare are selected by walking down the tree. An HTML diff report is generated
  from the results. The report template is the `textcompare_report.template` file located next to the
  `pgadmin3.exe` executable. Notes: the SQL creation text of sequences is ignored, and table partitions
  are not taken into account. Fully identical objects are hidden. Internal/service objects are ignored.
- Switched to new wxWidgets 3.0.4 DLL libraries compiled for VS2012. The `*.dll` files need to be
  updated.

## [2019-09-10]

Server Status window

### Added
- Added coloring of processes that are blocking other processes.

### Fixed
- Fixed a crash of the Server Status window when the DBMS terminates abnormally.

Query window

### Added
- Added a filter in the query results window. Activated by double-clicking a cell, whose text becomes
  the filter condition. Cleared from the context menu. Holding Alt inverts the filter condition (hide
  rows containing the value).
- To avoid delays when retrieving object information, the client parameter `SET lock_timeout=15000` is
  now set for the service/utility connection.

## [2019-09-04]

### Added
- Added support for PostgreSQL 12.
- Added display of additional options for indexes.
- Added an alternate button in the query window showing the current mode, Transaction (T) or AutoCommit
  (A).

### Fixed
- Fixed a bug in the object search window when searching within comments.

## [2019-03-11]

### Fixed
- Fixed display of foreign tables.

## [2019-02-09]

### Added
- Added copying of SQL in HTML format (preserving color).
- Added a commented-out list of columns with types to the SQL output for tables.

### Fixed
- Fixed some bugs.

## [2019-01-26]

### Fixed
- Fixed application crashes when typing "(" in the code editing window.
- Sped up opening of the "new function" and "new table" dialogs.

## [2019-01-11]

### Fixed
- Fixed application crashes when opening a table via F4.

## [2018-12-28]

### Added
- Switched to wxWidgets 3.0; the exe file version will be located in `Release_(3.0)`.
- In the text representation of the plan, nodes can now be collapsed.
- When building a plan with timing measurements, row headers now show the percentage of execution time
  for the node (only the node's own operation, not its child nodes).

## [2018-12-11]

### Added
- Added tree search via F4 on selected text, and if the object is found, it is opened. If the query runs
  longer than 2 minutes, the window will flash once the query completes.
- When opening a function, focus is now set directly to the Code tab.

## [2018-12-09]

### Added
- Autocomplete: added function names, and the ability to substitute table column names taken from the
  FROM clause.
- While typing a function name, a list of that function's parameters is now shown.

## [2018-12-05]

### Added
- Added support for the `pgpro_scheduler` extension. In the Statistics section, information about the
  last completed job is displayed. The information is taken from the `pg_log` log table, provided the
  table exists and is visible and the "Enabled ASUTP style" flag is set. The following query result is
  displayed: `select log_time,detail critical,message,application_name from pg_log l where l.log_time>'$Started'::timestamp - interval '1min' and l.log_time<'$Finised' and hint='$name'`.
- In query result output, cells whose values contain a newline character (`\n`) are now highlighted.

### Fixed
- Fixed a bug in exporting query results to Excel, related to saving intervals.
- Refreshing the schema no longer blocks the interface while a long-running `cluster` operation is in
  progress on a table. However, pressing F5 on the table itself still blocks, due to `pg_def*` functions
  being locked while retrieving table information.

## [2018-11-01]

### Added
- Added display of publications.
- Added background color change for an uncommitted transaction.
- Changed the hotkeys for Commit/Rollback.

## [2018-10-10] - Initial fork

This project supports pgAdmin3 v1.22. Support is added as bugs surface in the original v1.22 version, or
when these capabilities are needed. As of 10.10.2018, around 70 source files have been modified.

For convenience, the latest compiled executable will be located in the `Release` directory. To use it,
simply replace the original `pgAdmin3.exe`.

Only the original PostgreSQL 12 and PostgresPro Enterprise versions will be supported.

The full version of pgAdmin3 can be found at https://github.com/postgres/pgadmin3.git.

### Added
- Export of query results to Excel.
- Added selection of the query to execute under the cursor (Auto-Select).
- Added configurable autoreplace (in the menu Edit → Manage autoreplace).
- Added autosaving of bookmark/tab contents after executing a query.
- Added the ability to give a bookmark a name and to make a bookmark auto-load for a specific database.
- Added support for procedures.
- Added support for partitioning (display only, in the object tree).
- Removed the display of nodes with status "Never execute" on the graphical plan tab, though they are
  still present in the tabular view.
