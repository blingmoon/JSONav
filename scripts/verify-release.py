#!/usr/bin/env python3
"""Check the package staging root without installing or launching user apps."""
import pathlib
import plistlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
app = root / 'Applications/JSONLook.app'
cli = root / 'usr/local/bin/jsonlook'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'local.blingmoon.JSONav.personal'
assert info['CFBundleDisplayName'] == 'JSONLook'
assert info['CFBundleShortVersionString'] == pathlib.Path('config/PersonalVersion.txt').read_text().strip()
assert info['LSMinimumSystemVersion'] == '26.2'
for binary in (app / 'Contents/MacOS' / info['CFBundleExecutable'], cli):
    assert subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() == 'arm64'
    subprocess.run(['codesign', '--verify', '--strict', str(binary)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True)
assert plistlib.loads(result.stdout) == {
    'com.apple.security.app-sandbox': True,
    'com.apple.security.files.user-selected.read-write': True,
}
assert not list(app.rglob('*.debug.dylib'))
assert 'Usage: jsonlook' in subprocess.check_output([str(cli), '--help'], text=True)
print('Release payload: arm64, version, identity, signature, sandbox and CLI checks passed')
