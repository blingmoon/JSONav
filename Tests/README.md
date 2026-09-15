# Parser regression checks

Run all checks with `bash scripts/test-local.sh` (requires Xcode and a macOS GUI session).
This includes exact-token field edits, invalid/stale-edit rejection, and an actual
NSTextView integration check for binding updates, undo, and redo after highlighting.

From the repository root, with Xcode selected for this invocation:

```bash
mkdir -p build/number-tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -swift-version 5 -default-isolation MainActor -parse-as-library \
  JSONav/Models/JSONNode.swift JSONav/Models/JSONParser.swift \
  Tests/JSONParserNumberTests.swift -o build/number-tests/regression
build/number-tests/regression
```

This checks tree display of large integers, signed/unsigned 64-bit limits,
ordinary numbers, booleans, and nested values. It does not assert preservation
of original number spelling or arbitrary precision beyond JSONSerialization.

For read-only preview projection (folding, search through collapsed branches,
escaped strings, arrays, and distinct paths with dots):

```bash
mkdir -p build/preview-tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -swift-version 5 -default-isolation MainActor -parse-as-library \
  JSONav/Models/JSONNode.swift JSONav/Models/JSONParser.swift \
  JSONav/Models/JSONPreviewDocument.swift Tests/JSONPreviewTests.swift \
  -o build/preview-tests/regression
build/preview-tests/regression
```

`JSONImportTests` covers delivery before the view exists, exact Unicode and multiline
text, invalid JSON preservation, a single pending slot, accepting/rejecting buffer
replacement, rejecting further arrivals during a decision, cancellation, quit,
duplicate delivery, and the 10 MiB text limit. It tests the protocol and controller;
real app sandbox delivery and window lifecycle require the manual checks in
`docs/cli-import.md`.

`JSONImportViewTests` hosts the real ContentView and checks that its unsaved-state
binding keeps subsequent imports buffered, including after accepting an earlier
import. It uses a disposable app identity, not either installed app.
