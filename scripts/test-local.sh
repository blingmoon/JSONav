#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/tests
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then architecture=arm64; fi
for test in JSONParserNumberTests JSONPreviewTests JSONSourceEditTests JSONFieldUndoTests JSONImportTests; do
  arch "-$architecture" /usr/bin/xcrun swiftc \
    -swift-version 5 -default-isolation MainActor -parse-as-library \
    JSONav/Models/*.swift JSONav/Utilities/JSONSyntaxHighlighter.swift \
    JSONav/Utilities/SyntaxHighlightingTextView.swift "Tests/$test.swift" \
    -o "build/tests/$test"
  "build/tests/$test"
done

# Give the real SwiftUI view test an app identity, as the import protocol requires.
ui_app="$PWD/build/tests/UI.noindex/ImportTests.app"
mkdir -p "$ui_app/Contents/MacOS"
cat > "$ui_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.jsonav.import-tests</string>
<key>CFBundleExecutable</key><string>import-tests</string>
</dict></plist>
PLIST
arch "-$architecture" xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
  JSONav/Models/*.swift JSONav/Views/*.swift JSONav/Utilities/*.swift \
  Tests/JSONImportViewTests.swift -o "$ui_app/Contents/MacOS/import-tests"
"$ui_app/Contents/MacOS/import-tests"
