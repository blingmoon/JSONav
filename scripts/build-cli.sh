#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mode="${1:-install}"
if [[ "$mode" != install && "$mode" != --build-only ]]; then
  echo 'Usage: bash scripts/build-cli.sh [--build-only]' >&2
  exit 2
fi
mkdir -p build/cli
# Remember which old user commands match our previous build before recompiling.
legacy_commands=()
if [[ "$mode" == install ]]; then
  for command_name in jsonlook jsonav; do
    legacy="$HOME/.local/bin/$command_name"
    if [[ -f "$legacy" && ! -L "$legacy" && -f "build/cli/$command_name" ]] && cmp -s "$legacy" "build/cli/$command_name"; then
      legacy_commands+=("$legacy")
    elif [[ -e "$legacy" || -L "$legacy" ]]; then
      echo "Review and move $legacy aside before installing; it could shadow /usr/local/bin/jsonlook." >&2
      exit 1
    fi
  done
fi
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then architecture=arm64; fi
arch "-$architecture" xcrun swiftc -O -swift-version 5 -target "$architecture-apple-macosx26.2" \
  JSONav/Models/JSONImportEnvelope.swift CLI/main.swift -o build/cli/jsonlook
codesign --force --sign - build/cli/jsonlook
if [[ "$mode" == --build-only ]]; then
  echo "$PWD/build/cli/jsonlook"
  exit 0
fi
# Compile without elevated privileges; elevate only the installation if necessary.
if [[ -d /usr/local/bin && -w /usr/local/bin ]]; then
  install -m 755 build/cli/jsonlook /usr/local/bin/jsonlook
else
  sudo /usr/bin/install -d -m 755 /usr/local/bin
  sudo /usr/bin/install -m 755 build/cli/jsonlook /usr/local/bin/jsonlook
fi
# macOS Bash 3.2 treats an empty array as unset under nounset.
for legacy in ${legacy_commands[@]+"${legacy_commands[@]}"}; do
  archive_dir=$(mktemp -d "$PWD/build/cli/PreviousCommand.XXXXXX")
  mv "$legacy" "$archive_dir/$(basename "$legacy")"
  echo "Archived $legacy to $archive_dir" >&2
done
echo /usr/local/bin/jsonlook
