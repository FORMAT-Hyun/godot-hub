# Godot Hub

A launcher that manages your Godot Engine projects and editor versions in one place, built with Godot 4.7.
It looks and works like Godot's own project manager (tabs: Projects · Installs · Asset Library), with Godot's colors, fonts and icons.
The original planning document is in [PLAN.md](PLAN.md).

> Godot Hub is an unofficial tool. "Godot" and the Godot logo are trademarks of the Godot Foundation.

## Install

Download `GodotHub-<version>-Setup.exe` from the [releases page](https://github.com/FORMAT-Hyun/godot-hub/releases/latest) and run it.
It installs for your user account without admin rights and adds a Start menu shortcut (and a desktop shortcut if you choose).
Uninstall it from Windows Settings > Apps. To use it without installing, download `GodotHub-<version>-portable.zip`, extract it and run `GodotHub.exe`.

Windows only for now. The executable is not code-signed, so SmartScreen may warn the first time ("More info" > "Run anyway").

## Features

- **Projects**: add a folder, scan subfolders for projects, drag & drop folders onto the window, search, sort, favorites,
  per-project editor version, double-click to open, warning before opening with a different version.
  Side menu like the Godot project manager: Edit (verbose · recovery mode · another version), Run, Rename, Duplicate,
  Manage Tags (search with `tag:name`), Remove (optionally move the folder to the Recycle Bin), Remove Missing, Donate.
- **Installs**: install Stable / pre-release / archived versions (standard and .NET) from GitHub (`godotengine/godot-builds`),
  choose the install folder, register an existing executable, default version (☆), self-contained mode (`._sc_`),
  properties window, uninstall (moves to the Recycle Bin).
  - **Export templates**: install, manage and remove them per editor. They go straight into the folder that editor
    reads (`export_templates/<version>`), including self-contained editors.
  - **Editor settings**: by default the Hub opens its own settings window. It reads each version's setting names, option lists,
    ranges, defaults and shortcuts from that editor (in the Hub's language) and edits the settings file directly — it also works
    for versions that have never been opened. In Settings you can switch to opening the real Godot editor settings window instead.
    Tested with Godot 4.0–4.7.
- **Asset Library**: browse templates, projects and demos from the Godot Asset Library (search, sort, category, Godot version),
  then download one and add it as a new project — the same as the Asset Library tab in Godot's project manager.
- **New project**: the same "Create New Project" window as Godot's project manager — project name, path with
  "Create Folder", renderer (Forward+ / Mobile / Compatibility) with its description, version control metadata (Git),
  plus the editor version to create it with.
- **Languages**: every language the Godot editor supports (39) plus Korean. It follows the system language by default
  and can be changed in Settings. Arabic, Persian and Hebrew use a right-to-left layout.
- **Windows**: dialogs such as Settings, New Project and Install Editor open as separate windows you can move anywhere.
- **Settings**: language, install folder, default project folder, what the Hub does after opening an editor,
  UI scale, editor settings window mode, GitHub token.

Hub data is stored in `%APPDATA%\GodotHub\hub_data`, and editors are installed to `%LOCALAPPDATA%\GodotHub\Editors` by default.

## Run from source

1. Open this folder with the Godot 4.7 editor and press F5.
   (The first time, open it in the editor or run `--import` once so class names are registered.)
2. Or from the command line:

```powershell
& "<path>\Godot_v4.7-stable_win64.exe" --path "<path to this folder>"
```

## Build the installer

Requires the Godot 4.7 Windows export templates and [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```powershell
& "<path>\Godot_v4.7-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build\GodotHub.exe
```

```powershell
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\GodotHub.iss
```

The installer is written to `build\GodotHub-<version>-Setup.exe`.

## Translations

UI strings are written in Korean in the code and wrapped with `L.t("...")`.

- `i18n/keys.json` — the source strings (append-only, so existing translations stay aligned)
- `i18n/<language>.json` — translations in the same order
- `i18n/patches/*.json` — new strings added in a release; apply with `python i18n/apply_patch.py <patch>`
- `python i18n/check.py` — checks every language file (count, `%s` / `%d` placeholders, leading/trailing whitespace)

Translations were written by hand but have not been reviewed by native speakers. Corrections are welcome — please open an issue or pull request.

## Development options (after `--`)

| Option | Description |
|------|------|
| `--hub-data=<folder>` | Use a separate data folder instead of the real one |
| `--hub-page=installs` | Start page (`projects` / `installs` / `assets`) |
| `--hub-dialog=new` | Open a window at startup (`new` / `install` / `settings` / `editor-settings` / `properties`) |
| `--hub-select=<n>` | Select the n-th row on the start page |
| `--hub-es-search=<text>` | With `--hub-dialog=editor-settings`: pre-fill the search box |
| `--hub-asset=<id>` | With `--hub-page=assets`: open that asset's details |
| `--hub-embed-dialogs` | Draw dialogs inside the main window (so `--hub-screenshot` captures them) |
| `--hub-screenshot=<png>` | Save the main window to a PNG and quit (`--hub-shot-delay=<seconds>`) |

## Tests

Each test is a scene run headless, for example:

```powershell
& "<path>\Godot_v4.7-stable_win64_console.exe" --headless --path . res://tests/test_project_ops.tscn -- --hub-data=<test data folder> --test-project=<copy of a project>
```

| Scene | What it checks |
|------|------|
| `tests/test_download.tscn` | Downloading and installing an editor |
| `tests/test_project_ops.tscn` | Rename, tags, duplicate, remove missing |
| `tests/test_editor_settings.tscn` | Hub settings window: reading, saving values and shortcuts, creating the settings file |
| `tests/test_templates.tscn` | Installing and removing export templates (real download) |
| `tests/test_new_project.tscn` | Creating projects from the New Project window |
| `tests/test_asset.tscn` | Downloading an Asset Library project and adding it (real download) |

## Structure

```
scripts/core/   Hub (data) · Releases (GitHub list) · Downloads (queue) · settings helper · translations · parsers
scripts/ui/     main window · pages · dialogs · theme · icons
i18n/           translations
installer/      Inno Setup script and icon
tests/          test scenes
```

See [THIRD_PARTY.md](THIRD_PARTY.md) for the licenses of the Godot icons and logo.
