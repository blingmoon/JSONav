#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/tests
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then architecture=arm64; fi
for test in JSONParserNumberTests JSONPreviewTests JSONSourceEditTests JSONFieldUndoTests; do
  arch "-$architecture" /usr/bin/xcrun swiftc \
    -swift-version 5 -default-isolation MainActor -parse-as-library \
    JSONav/Models/*.swift JSONav/Utilities/JSONSyntaxHighlighter.swift \
    JSONav/Utilities/SyntaxHighlightingTextView.swift "Tests/$test.swift" \
    -o "build/tests/$test"
  "build/tests/$test"
done
