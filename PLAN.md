# Godot Hub — Planning document (v0.1)

> A Godot Engine launcher that manages **projects + editor versions** in one place, like Unity Hub.
> Layout from Unity Hub; look (theme, colors, fonts, icons) from the Godot editor.

> **Note:** this is the original plan, kept for reference. The app has changed since then:
> the layout now follows Godot's own project manager (top tabs instead of a sidebar), the Learn/Community pages were dropped,
> an Asset Library tab and export template management were added, the Hub has its own editor settings window,
> and the UI is translated into every language the Godot editor supports. See [README.md](README.md) for the current feature list.

---

## 1. Goals

| # | Goal | Description |
|---|------|------|
| 1 | One place for projects | See scattered Godot projects in a single list; search, sort, favorite, launch |
| 2 | Editor version management | Download, install and remove several Godot versions (Stable / RC / Beta / Dev, standard / .NET) from the Hub |
| 3 | Per-project version | Choose the editor version for each project and open it with that version |
| 4 | Feels like Godot | A UI that feels familiar when coming from the Godot editor |

**Out of scope for now:** asset store, accounts/login, cloud builds, license management (Unity Hub has them; Godot doesn't need them).

---

## 2. Tech stack — **build it with Godot 4.x** (recommended)

| Option | Pros | Cons |
|--------|------|------|
| **Godot 4.x + GDScript** ✅ | Reuses the Godot editor theme, so the "Godot feel" comes for free. Godot's own project manager is built with Godot. `HTTPRequest`, `ZIPReader`, `OS.create_process` and `ConfigFile` cover everything. Ships as a single executable | Layout takes a bit more work than a web UI |
| Tauri / Electron | Web UI is quick to build | The Godot look has to be recreated in CSS; Electron is large |
| C# WPF / WinUI | Native on Windows | Far from the Godot look; hard to go cross-platform |

- Language: GDScript (heavy work can move to C# or GDExtension later)
- Target OS: **Windows first**, then Linux / macOS (keep path and file name rules abstracted)
- Reference: similar open-source tools exist — *Godots* (a launcher built with Godot) and *GodotEnv* (CLI)

---

## 3. Screens (Unity Hub layout)

```
┌───────────────────────────────────────────────────────────────────────┐
│ [G] Godot Hub                                              [⚙] [─][□][×]│
├──────────────┬────────────────────────────────────────────────────────┤
│              │  Projects                           [Import ▾] [New project] │
│  📁 Projects  │  ┌──────────────────────────────┐                        │
│  🧩 Installs  │  │ 🔍 Search                     │   [List▦] [Sort ▾]     │
│  📚 Learn     │  └──────────────────────────────┘                        │
│  🌐 Community │  ★  Name            Modified        Editor version    ⋯  │
│              │  ─────────────────────────────────────────────────────  │
│              │  ☆ [ico] MyGame      2 hours ago   [4.3-stable  ▾]   ⋯  │
│              │         D:\Games\MyGame                                 │
│              │  ★ [ico] Platformer  Yesterday     [4.4-stable  ▾]   ⋯  │
│              │         D:\Dev\Platformer             ⚠ version missing │
│              │                                                        │
├──────────────┤                                                        │
│ v0.1.0       │                                                        │
└──────────────┴────────────────────────────────────────────────────────┘
```

### 3.1 Common frame
- **Left sidebar**: Projects / Installs / Learn / Community tabs, Hub version at the bottom
- **Top right**: the page's main buttons (one blue primary button plus secondary buttons, like Unity Hub)
- **Settings gear**: top right of the window
- **Download progress**: a progress bar under the sidebar or at the top (where Unity Hub shows downloads)

### 3.2 Projects page
- Columns: ★ favorite · icon · name + path · modified · editor version (dropdown) · `⋯` menu
- Double-click a row → open the editor with the assigned version
- `⋯` menu: show in Explorer / open with another version / run (game without editor) / remove from list / copy path
- **Import ▾**: add folder / scan folder (find `project.godot` in subfolders)
- Projects that need a version that isn't installed get a ⚠ mark and an "Install" shortcut
- Drag & drop a folder onto the window to add it

### 3.3 New project window (Unity Hub's template picker layout)
```
┌─────────────────────────────────────────────────────────────┐
│ New project                     Editor version: [4.4-stable ▾] │
├──────────────┬──────────────────────────────┬───────────────┤
│ All           │  [Forward+]  [Mobile]  [Compat]│ Preview/notes │
│ 3D           │                                │               │
│ 2D           │  (renderer / template cards)    │ Project name  │
│ My templates │                                │ [_________]   │
│              │                                │ Location      │
│              │                                │ [D:\...] [📁] │
│              │                                │ ☑ Init Git    │
├──────────────┴──────────────────────────────┴───────────────┤
│                                       [Cancel] [Create project] │
└─────────────────────────────────────────────────────────────┘
```
- Renderer: Forward+ / Mobile / Compatibility
- Version control: none / Git (creates `.gitignore` and `.gitattributes`)
- Later: my templates (register a folder as a template)

### 3.4 Installs page
```
  Installs                                         [Locate] [Install editor]
  [All] [Stable] [Pre-release] [.NET]
  ─────────────────────────────────────────────────────────────
  [G] Godot 4.4-stable          D:\GodotHub\Editors\4.4-stable     ⚙
      Windows · standard · export templates ✔
  [G] Godot 4.3-stable (.NET)   D:\GodotHub\Editors\4.3-stable-mono ⚙
      Windows · .NET · export templates ✖
```
- **Install editor** → version list window (tabs: official releases / pre-releases / archive)
  - Standard / .NET choice, "also download export templates" checkbox (like Unity's "add modules")
- **Locate**: register a `Godot_*.exe` already on the PC
- ⚙ menu: add export templates / show in Explorer / set as default / remove

### 3.5 Learn / Community pages
- Link cards to the official docs, demo projects, forum, Discord, etc. (`OS.shell_open`)
- Low priority — start with a list of links

### 3.6 Settings
- Editor install folder (default `%LOCALAPPDATA%\GodotHub\Editors`)
- Default location for new projects
- Language (Korean / English)
- What the Hub does after launching an editor: stay / minimize / quit
- Whether to install editors in **self-contained mode** (see 5.4)
- GitHub token (optional, to raise the API rate limit)

---

## 4. UI style — "Godot feel"

- Use the Godot 4 default editor theme colors
  - background `#202531` / panels `#262c3b` / separators around `#363d4a`
  - accent (primary buttons, selected rows) `#478cbf` (Godot blue)
- Font: the Godot editor default (Noto Sans family; Noto Sans KR for Korean)
- Icons: Godot editor SVG icon style (single-color line icons)
- Manage everything with one `Theme` resource (`hub_theme.tres`) → a light theme can be added later
- HiDPI: UI scale option in Settings

---

## 5. Core features

### 5.1 Editor downloads
- Source: the GitHub `godotengine/godot-builds` releases API (it has all Stable, RC, Beta and Dev builds)
  - `GET https://api.github.com/repos/godotengine/godot-builds/releases`
  - Anonymous requests are limited to 60 per hour → **cache the result locally** (e.g. 6 hours), use a token if needed
- File names (Windows):
  - standard: `Godot_v{ver}_win64.exe.zip`
  - .NET: `Godot_v{ver}_mono_win64.zip`
  - export templates: `Godot_v{ver}_export_templates.tpz` (.NET: `_mono_export_templates.tpz`)
- Flow: download (`HTTPRequest.download_file`, with progress) → integrity check with `SHA512-SUMS.txt` → extract with `ZIPReader` (on a thread) → add to the installs list
- Download queue: several requests run in order and can be canceled

### 5.2 Reading projects (`project.godot`)
- Parse with `ConfigFile`
  - `[application] config/name` → name
  - `config/icon` → icon (convert the `res://` path relative to the project folder)
  - `config/features` → version and renderer from `PackedStringArray("4.3", "Forward Plus")`
  - `config_version` = 5 → Godot 4.x, 4 → Godot 3.x
- Modified time: from `project.godot` or the folder
- The version the Hub assigns is stored only in Hub data (project files are not touched)
- Auto-matching: when a project is first added, pick the installed version closest to its `config/features` version

### 5.3 Launching the editor
- `OS.create_process(editor_exe, ["--path", project_dir, "--editor"])`
- Run the game only: `["--path", project_dir]`
- Keep the PID to show "running" (`OS.is_process_running`)
- Warn when opening a project that is already open

### 5.4 Per-version settings (optional)
- If a `._sc_` file sits next to the executable, Godot runs in **self-contained mode** → editor settings and export templates are stored in that folder
- When on, editor settings and plugin caches don't mix between versions
- When off, everything shares `%APPDATA%\Godot` as usual
  - in that case export templates go to `%APPDATA%\Godot\export_templates\{4.3.stable}\`

### 5.5 Creating a new project
- Create the folder → write `project.godot` (`config_version=5`, name, features, renderer) → copy the default `icon.svg`
- With Git: create `.gitignore` (`.godot/` etc.) and `.gitattributes`, run `git init` (if Git is installed)
- Open it with the chosen editor right away

---

## 6. Data storage

Under `user://` (the project's user data folder is set to `GodotHub`):

```
hub_data/
├─ settings.json      # paths, language, behavior options
├─ installs.json      # [{id, version, channel, mono, path, exe, templates}]
├─ projects.json      # [{path, name, editor_id, favorite, last_opened}]
└─ cache/
   ├─ releases.json   # GitHub release cache + fetch time
   └─ icons/          # project icon thumbnails
```

- Projects or editors whose path disappeared are shown as "not found" at startup (not deleted automatically)

---

## 7. Folder structure (planned)

```
godot-hub/
├─ project.godot
├─ PLAN.md
├─ assets/
│  ├─ theme/hub_theme.tres
│  ├─ fonts/
│  └─ icons/
├─ scenes/
│  ├─ main.tscn              # sidebar + page container
│  ├─ pages/
│  │  ├─ projects_page.tscn
│  │  ├─ installs_page.tscn
│  │  └─ learn_page.tscn
│  ├─ dialogs/
│  │  ├─ new_project_dialog.tscn
│  │  ├─ install_editor_dialog.tscn
│  │  └─ settings_dialog.tscn
│  └─ components/            # project row, install row, progress bar, ...
└─ scripts/
   ├─ core/
   │  ├─ hub_data.gd         # save/load (Autoload)
   │  ├─ project_scanner.gd  # project.godot parsing
   │  ├─ editor_launcher.gd
   │  ├─ release_api.gd      # GitHub API + cache
   │  └─ download_manager.gd # download queue, hash check, extraction
   └─ ui/
```

---

## 8. Milestones

| Stage | Work | Done when |
|------|------|-----------|
| **0. Skeleton** | Create the Godot project, theme, sidebar + empty page switching | The window opens and tabs switch |
| **1. Project list** | Add/scan folders, parse `project.godot`, list · search · sort · favorites, saving | My projects show up and persist after a restart |
| **2. Register editors + launch** | Register existing executables, per-project version, double-click to launch | Open a project with any version from the Hub → **this is the MVP** |
| **3. Editor downloads** | GitHub API, version list window, queue · progress · hash check · extraction | Install/remove 4.x Stable/.NET inside the Hub |
| **4. New project** | New project window, renderer choice, Git setup | Projects created by the Hub open correctly in Godot |
| **5. Extras** | Export templates, self-contained mode, running indicator, drag & drop, Learn page | — |
| **6. Polish** | Korean/English translation, new Godot version notice, Hub self-update check, release executable | Runs from a single exe on another PC |
| 7. Later | Linux/macOS, my templates, CLI commands (`godothub open MyGame`) | — |

---

## 9. Expected problems

| Problem | Plan |
|------|------|
| GitHub API rate limit (60 per hour) | Cache + optional token |
| UI freezing while extracting large files (.NET builds are hundreds of MB) | Extract on a `Thread`/`WorkerThreadPool`, report progress with signals |
| Interrupted downloads | Download to a temp file, move it only after it completes and passes the hash check, retry on failure |
| Godot 3 projects | Detect with `config_version=4` and only offer 3.x editors |
| Accidentally upgrading a project by opening it with a newer version | Confirm before opening with an editor newer than the project |
| Non-ASCII characters and spaces in paths | Include launch arguments and file paths in testing |

---

## 10. Decisions needed

1. Tech stack: go with Godot 4.x + GDScript? (recommended)
2. First OS: Windows only at first?
3. Should self-contained mode (per-version settings) be on by default?
4. Name ("Godot Hub" for now — may need adjusting so it doesn't look official under the Godot trademark guidelines)
