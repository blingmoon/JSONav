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
