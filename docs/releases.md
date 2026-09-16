# Building and publishing JSONLook

The release package contains the daily app and CLI, both arm64-only. It requires
macOS 26.2 or later. It installs `/Applications/JSONLook.app` and
`/usr/local/bin/jsonlook` together; the Test app remains independent.
Neither Xcode nor a Swift development toolchain is required on the receiving Mac.

JSONLook begins its independent release series at **0.0.1** (`v0.0.1`).
Earlier Personal 0.1.0/0.2.0 builds were development versions, not JSONLook
package releases. Bundle IDs and user data locations remain unchanged. The
installer replaces the app and CLI together, including when installing this
first release over an older development build with a higher version number.
This also means the installer currently permits deliberate version rollback.

## Local build

```sh
bash scripts/test-local.sh
bash scripts/build-package.sh
```

The output is `build/packages/JSONLook-<version>-macos-arm64.pkg` and its
`.sha256` file. Packaging does not install anything or replace a running app.
The native installer requests administrator authorization. Save and quit the
daily app first; installation refuses a running editor, unsupported hardware,
older macOS, a different app at the destination, or destination symlinks.
The package replaces the whole app bundle instead of merging stale files.

Both source builds and package installs use `/usr/local/bin/jsonlook`.
`bash scripts/build-cli.sh` builds without elevation, requests `sudo` only if
needed for installation, and archives `~/.local/bin/jsonlook` / `jsonav` only
when they match the previous CLI build in that checkout. Unknown files are left
untouched and installation stops with instructions. Run this migration before
installing the package on a previously configured development Mac.

The package does not edit user home directories. It rejects old CLI locations
for the logged-in desktop user rather than allowing them to shadow the installed
command. Without the original checkout, move the old commands to a backup
location yourself. Other user accounts must check their own PATH. Use
`type -a jsonlook` and `/usr/local/bin/jsonlook --help` to verify resolution;
restart your shell if it cached the old path. Alfred should use the absolute path.

A previous app named JSONav Personal is not removed by the package. The local
`build-local.sh release` migration can archive it; alternatively retain a backup
outside Applications. The unchanged bundle identifier preserves sandbox data.

## Release from main

1. Update `config/PersonalVersion.txt` to an unused `X.Y.Z` version (also keep
   the Xcode project marketing version in sync for direct development builds) and merge
   the tested changes, including the workflow, into your own `main`.
2. Tag the merged commit (example version only):

   ```sh
   git switch main
   git pull --ff-only
   git tag -a v0.0.1 -m "JSONLook v0.0.1"
   git push origin v0.0.1
   ```

3. Open GitHub Actions → **Release draft**. The workflow checks that the tag
   matches the version file and its commit belongs to `main`, runs regressions,
   builds the app and CLI, packages them, and installs/tests the package on a
   disposable GitHub runner. A failure prevents draft creation.
4. Open GitHub Releases → the draft. Download and test the installer, edit the
   release notes, then click **Publish release**. No automatic publication occurs.

A push/merge to `main` alone does not publish or package a release. Tags that do
not start with `v` do not trigger this workflow. Re-running a successful tag can
refresh its draft assets; it refuses to change an already published release.
Use a new version for subsequent releases instead of moving published tags.

The workflow uses the standard arm64 `macos-26` runner and selects Xcode 26.6
explicitly. Runner availability and Xcode images can change; update the selected
version deliberately and re-run tests if GitHub retires that toolchain. Local
builds also work with the verified Xcode 27.0 toolchain. Only the draft job gets
`contents: write`; the build job cannot publish. No Apple signing secrets or
personal access token are required, but the repository must allow Actions and
its token to create releases.

## Signing and source

The app and CLI are ad-hoc signed; the installer is unsigned and not notarized.
A downloaded package may require approval in System Settings → Privacy &
Security. This pipeline does not add app auto-update or Apple notarization.
The installer includes the GPLv3 license and upstream attribution. Publish it
with its exact source tag, available through the release source archives.
