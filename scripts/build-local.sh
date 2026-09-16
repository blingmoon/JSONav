#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# A channel identifies the installed app, independently of Xcode's build configuration.
channel="${1:-test}"
mode="${2:-install}"
if [[ "$mode" != install && "$mode" != --build-only ]]; then
  echo 'Usage: bash scripts/build-local.sh [test|release] [--build-only]' >&2
  exit 2
fi
case "$channel" in
  release)
    name='JSONLook'
    legacy_names=('JSONav Personal')
    legacy_paths=("/Applications/JSONav Personal.app" "$HOME/Applications/JSONav Personal.app")
    identifier=local.blingmoon.JSONav.personal
    destination="/Applications/$name.app"
    ;;
  test)
    name='JSONLook Test'
    legacy_names=('JSONav Personal Test')
    legacy_paths=("$HOME/Applications/JSONav Personal Test.app")
    identifier=local.blingmoon.JSONav.personal.test
    destination="$HOME/Applications/$name.app"
    ;;
  *) echo "Usage: bash scripts/build-local.sh [test|release]" >&2; exit 2 ;;
esac
version="$(cat config/PersonalVersion.txt)"
derived="$PWD/build/Personal-$channel.noindex"
log="$PWD/build/$channel-build.log"
mkdir -p "$derived"
architecture="$(uname -m)"
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
  architecture=arm64
fi
# Both channels use the same optimized, sandboxed configuration for representative testing.
if ! arch "-$architecture" /usr/bin/xcrun xcodebuild \
  -project JSONav.xcodeproj -scheme JSONav -configuration Release \
  -derivedDataPath "$derived" -destination "platform=macOS,arch=$architecture" \
  PRODUCT_NAME="$name" PRODUCT_BUNDLE_IDENTIFIER="$identifier" \
  INFOPLIST_KEY_CFBundleDisplayName="$name" MARKETING_VERSION="$version" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  CODE_SIGN_ENTITLEMENTS="$PWD/config/Local.entitlements" DEVELOPMENT_TEAM= \
  ENABLE_FILE_ACCESS_DOWNLOADS_FOLDER=NO ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO \
  build > "$log" 2>&1; then
  tail -n 60 "$log" >&2
  exit 1
fi
product="$derived/Build/Products/Release/$name.app"
codesign --verify --deep --strict "$product"
if [[ "$mode" == --build-only ]]; then
  echo "$product"
  exit 0
fi
mkdir -p "$(dirname "$destination")"
# Build first, but never replace a running app or discard its unsaved document.
for running_name in "$name" "${legacy_names[@]}"; do
  if /usr/bin/pgrep -f "/$running_name.app/Contents/MacOS/" >/dev/null; then
    echo "Build ready at $product. Save your work, quit $running_name, then rerun to install." >&2
    exit 1
  fi
done
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
backup="$derived/PreviousInstall-$(date +%Y%m%d-%H%M%S).app"
if [[ -e "$destination" ]]; then
  "$lsregister" -u "$destination" || true
  mv "$destination" "$backup"
fi
# Replace the whole bundle; retain the previous version in an unindexed backup.
if ! ditto "$product" "$destination" || ! codesign --verify --deep --strict "$destination"; then
  rm -rf "$destination"
  if [[ -e "$backup" ]]; then mv "$backup" "$destination"; fi
  exit 1
fi
# Keep the bundle identifiers unchanged so the renamed apps retain sandbox data.
# Only archive an old installation belonging to this channel, never an unrelated app.
for legacy in "${legacy_paths[@]}"; do
  if [[ -e "$legacy" ]]; then
    old_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$legacy/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$old_identifier" == "$identifier" ]]; then
      "$lsregister" -u "$legacy" || true
      archive_dir=$(mktemp -d "$derived/LegacyInstall.XXXXXX")
      mv "$legacy" "$archive_dir/$(basename "$legacy")"
    fi
  fi
done
"$lsregister" -u "$product" || true
"$lsregister" -f "$destination"
echo "$destination (version $version)"
