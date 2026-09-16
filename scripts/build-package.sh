#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
[[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]] || { echo 'Build the arm64 package on Apple Silicon.' >&2; exit 1; }
version=$(cat config/PersonalVersion.txt)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected an X.Y.Z version.' >&2; exit 1; }
bash scripts/build-local.sh release --build-only
bash scripts/build-cli.sh --build-only
mkdir -p build/packages
work=$(mktemp -d "$PWD/build/packages/staging.XXXXXX")
trap 'rm -rf "$work"' EXIT
root="$work/root"
mkdir -p "$root/Applications" "$root/usr/local/bin" "$work/resources"
ditto build/Personal-release.noindex/Build/Products/Release/JSONLook.app "$root/Applications/JSONLook.app"
install -m 755 build/cli/jsonlook "$root/usr/local/bin/jsonlook"
# Verify architecture, identity and sandbox before publishing any installer.
python3 scripts/verify-release.py "$root"
cp LICENSE "$work/resources/LICENSE.txt"
cp scripts/installer/Welcome.txt "$work/resources/Welcome.txt"
pkgbuild --analyze --root "$root" "$work/components.plist"
python3 - "$work/components.plist" <<'PY'
import plistlib, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    components = plistlib.load(f)
# Replace the complete bundle with the package payload. Skipping only a newer
# app while installing an older CLI could leave incompatible versions together.
for component in components:
    component.update(BundleIsRelocatable=False, BundleIsVersionChecked=False,
                     BundleHasStrictIdentifier=True, BundleOverwriteAction='upgrade')
with open(path, 'wb') as f:
    plistlib.dump(components, f)
PY
pkgbuild --root "$root" --component-plist "$work/components.plist" \
  --scripts scripts/installer --identifier local.blingmoon.jsonlook.installer \
  --version "$version" --install-location / --ownership recommended "$work/JSONLook-component.pkg"
cat > "$work/Distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>JSONLook $version</title>
  <welcome file="Welcome.txt"/>
  <license file="LICENSE.txt"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
  <domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
  <volume-check><allowed-os-versions><os-version min="26.2"/></allowed-os-versions></volume-check>
  <choices-outline><line choice="jsonlook"/></choices-outline>
  <choice id="jsonlook" visible="false" title="JSONLook app and command"><pkg-ref id="local.blingmoon.jsonlook.installer"/></choice>
  <pkg-ref id="local.blingmoon.jsonlook.installer" version="$version" onConclusion="none">JSONLook-component.pkg</pkg-ref>
</installer-gui-script>
XML
output="$PWD/build/packages/JSONLook-$version-macos-arm64.pkg"
productbuild --distribution "$work/Distribution.xml" --resources "$work/resources" --package-path "$work" "$output"
(cd build/packages && shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256")
echo "$output"
