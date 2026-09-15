#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/cli "$HOME/.local/bin"
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then architecture=arm64; fi
arch "-$architecture" xcrun swiftc -O -swift-version 5 \
  JSONav/Models/JSONImportEnvelope.swift CLI/main.swift -o build/cli/jsonav
codesign --force --sign - build/cli/jsonav
install -m 755 build/cli/jsonav "$HOME/.local/bin/jsonav"
echo "$HOME/.local/bin/jsonav"
