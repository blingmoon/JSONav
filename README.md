# JSON Editor

A lightweight, native macOS JSON editor built with SwiftUI.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)

<p align="center">
  <img src="docs/screenshots/lightmode.png" width="800" alt="JSON Editor in Light Mode">
</p>

## Features

- **Tree View Navigation** — Collapsible sidebar displays your JSON structure at a glance
- **Syntax Highlighting** — Color-coded keys, strings, numbers, booleans, and nulls
- **Real-time Validation** — Instant feedback as you type with valid/invalid status
- **Cursor Sync** — Tree view highlights the node at your cursor position in the editor
- **Click to Navigate** — Click any node in the tree to jump to it in the editor
- **Format & Minify** — Toggle between pretty-printed and compact JSON
- **Dark Mode** — Full support for light and dark appearances
- **Drag & Drop** — Drop JSON files directly into the window
- **Native macOS** — Proxy icons, document editing state, keyboard shortcuts

## Installation

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Build from Source

```bash
git clone https://github.com/yourusername/json-editor.git
cd json-editor
open JSONav.xcodeproj
```

Build and run with `⌘R` in Xcode.

## Usage

| Action | Shortcut |
|--------|----------|
| New File | `⌘N` |
| Open File | `⌘O` |
| Save | `⌘S` |
| Toggle Dark Mode | Toolbar button |

### Tree View

The left panel shows your JSON as a navigable tree:

- **Click** a node to jump to its location in the editor
- **Filter** nodes using the search bar
- **Expand/collapse** objects and arrays with disclosure triangles

### Editor

The right panel is a full-featured text editor:

- Syntax highlighting updates as you type
- Cursor position syncs with the tree view
- Validation indicator shows JSON status in real-time

### Structure Editor (personal fork)

The three panes are **tree navigation | JSON source editor | structure editor**.
Use the **Structure Editor** toolbar button (right-sidebar icon) to toggle the
third pane. The **Tree Sidebar** button (left-sidebar icon) hides or shows the
left pane independently. Both visibility preferences persist across launches.
Drag the dividers to resize the panes.

- Objects and arrays collapse to `{…}` and `[…]`; use the plus/minus buttons to expand or collapse them.
- Search keys or values in the preview. Matching branches expand automatically;
  use the arrows or Enter to move between matching rows. Clear search to restore
  manual folding. The count represents matching rows, not individual text occurrences.
- Click a field name or scalar value to edit it in place. Press **Return** (or ✓)
  to commit and **Escape** (or ×) to discard. Values may be strings, numbers, booleans or null;
  enter strings without surrounding quotes. Use the source editor to add/remove
  fields or replace whole objects and arrays.
- Each committed change replaces only the selected token in the source, marks the
  document modified, and supports undo/redo. Unrelated formatting and number tokens
  are preserved. Duplicate keys and stale edits are rejected rather than overwriting
  another field. Invalid JSON hides the structure view until parsing succeeds.
- Folding and searching do not modify the source or saved JSON.
- Tree and preview numbers retain Foundation's parsed numeric representation,
  avoiding the former conversion of all numbers to `Double`. Original number
  spelling and arbitrary-precision parsing are not guaranteed.

### Build the personal app locally

With Xcode installed:

```sh
bash scripts/test-local.sh          # Regression tests
bash scripts/build-local.sh test    # Install ~/Applications/JSONav Personal Test.app
bash scripts/build-local.sh release # Install /Applications/JSONav Personal.app
```

The default channel is `test`. Both channels use optimized Release builds with
local ad-hoc signatures and sandbox/user-selected-file access, without debug
entitlements. Their separate bundle identifiers isolate preferences and sandbox
data; the release identifier stays unchanged from the earlier personal app.
Quit the target app before installation to protect unsaved input. Installing
release also archives the former `~/Applications/JSONav Personal.app`.

Intermediate bundles and previous installations stay in `build/*.noindex`.
Open the installed apps directly from Applications; no build-folder navigation is
needed. The script does not change the system's selected developer directory.

### Personal fork maintenance

- `main` retains the upstream baseline; keep personal changes on `codex/personal`.
- Commit and test changes on `codex/personal`, then install the test channel for
  interactive checks. Build the release channel from the validated commit.
- Set the personal version in `config/PersonalVersion.txt`. Mark a validated
  stable commit with an annotated tag such as `personal-v0.1.0`.
- Future upstream updates should first update `main`, then merge `main` into
  `codex/personal` and resolve any conflicts before testing again.
- Branches and tags are local until explicitly pushed. These local builds do not
  create a GitHub Release or publish a downloadable asset.

## Project Structure

```
JSONEditor/
├── JSONavApp.swift           # App entry point
├── Models/
│   ├── AppearanceMode.swift      # Light/dark mode handling
│   ├── JSONNode.swift            # Tree node model
│   └── JSONParser.swift          # JSON to tree conversion
├── Views/
│   ├── ContentView.swift         # Main layout
│   ├── TreeView.swift            # Sidebar tree
│   ├── EditableJSONView.swift    # Editor panel
│   └── SupportingViews.swift     # Shared components
└── Utilities/
    ├── JSONSyntaxHighlighter.swift
    ├── SyntaxHighlightingTextView.swift
    └── Extensions.swift
```

## Screenshots

<p align="center">
  <img src="docs/screenshots/darkmode.png" width="800" alt="JSON Editor in Dark Mode">
</p>

<p align="center">
  <img src="docs/screenshots/validation.png" width="800" alt="Real-time Validation">
</p>

<p align="center">
  <img src="docs/screenshots/compact.png" width="800" alt=“Compact view">
</p>

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

GPL-v3 License — see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with SwiftUI and AppKit for macOS.
