#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/docs docs/screenshots
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then architecture=arm64; fi
arch "-$architecture" xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library \
  JSONav/Models/*.swift JSONav/Views/*.swift JSONav/Utilities/*.swift \
  scripts/docs/RenderScreenshots.swift -o build/docs/render-screenshots
build/docs/render-screenshots
