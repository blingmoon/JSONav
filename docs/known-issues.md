# Known issues from the release-preparation review

These findings come from the current source review. The formatting dirty-state
issue was also reproduced by invoking the production formatting method with
observable bindings in an isolated probe. The existing regression tests passing
does not cover these scenarios. Fix and test the first two before treating
the first public release as ready for everyday editing.

- **Format/Compact does not mark a clean document as modified.** In
  `EditableJSONView.prettyPrint` / `minify`, assigning `rawJSON` bypasses
  `handleTextChange`, which normally updates the unsaved flag and character count.
  Formatting an otherwise clean document can therefore leave replacement guards
  treating it as unmodified. Formatting also uses Foundation serialization and
  sorts keys; it does not preserve original whitespace or number token spelling.
- **A pending validation can outlive the document it belongs to.**
  `EditableJSONView.debounceValidation` captures text, waits 300 ms, and later
  updates shared node/error bindings. There is no disappearance cancellation or
  current-document check. Replacing the editor through `editorRefreshID` during
  that interval can allow the previous result to overwrite the new document's
  tree/error state. The raw source itself is not written by this callback.
- **The README previously advertised Command-S, but no save shortcut is wired.**
  The current save entry is the toolbar button. The README now states this.
- **Close/quit protection is incomplete.** `WindowAccessor` sets the edited marker;
  the app has no explicit `windowShouldClose` / `applicationShouldTerminate`
  unsaved-document decision. A marker alone is not a save/restore implementation.
  Save before closing/quitting; the existing tests cover replacing/importing a
  document, not recovery of unsaved text after process termination.

The CLI preserves imported text. Ordinary file-open and explicit Format/Compact
still parse and reserialize it. Left-tree cursor navigation uses older path/string
scanning code; Unicode position correctness has not been comprehensively tested.

The GitHub release workflow has not yet run remotely, and an actual installed
old-version → new-version package upgrade has not been verified. Local package
payload, signature, architecture, installer compatibility and preflight checks
have passed. Keep the generated GitHub Release as a draft until installation and
upgrade checks are completed.
