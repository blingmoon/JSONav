Apple Silicon (arm64), macOS 26.2 or later. No Xcode required.

Download the `.pkg` installer to install **both**:
- `/Applications/JSONLook.app`
- `/usr/local/bin/jsonlook`

Save your work and quit JSONLook before upgrading. JSONLook Test is not replaced.
If migrating from `~/.local/bin/jsonlook` / `jsonav`, first run the updated
`scripts/build-cli.sh` in the original checkout, or move those old commands to a
backup location. Other Mac user accounts should also check for old commands.

This package is not Developer ID signed or notarized; the app and command are
ad-hoc signed. macOS may require manual approval in Privacy & Security.
The adjacent `.sha256` file provides a download integrity checksum.

Source for this build is the release tag in this repository. JSONLook is based
on brettnielsen/JSONav and remains licensed under GPLv3.

Maintainer: test the downloaded installer and replace this line with release
highlights before clicking **Publish release**. A draft is not publicly released.
