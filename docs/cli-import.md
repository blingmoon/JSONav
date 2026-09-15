# External JSON import

JSONav owns the `jsonav` command and the receiving app. Caller workflows and other
tools are outside this repository. No URL scheme, clipboard read or network service
is used. Install the command on each Mac with Xcode:

```sh
bash scripts/build-cli.sh
bash scripts/build-local.sh test
```

The command is at `~/.local/bin/jsonav`. Use its full path if `~/.local/bin` is not
on PATH; the build does not change shell configuration. Use `--test` until the
release app has been updated with `bash scripts/build-local.sh release`.

```sh
~/.local/bin/jsonav --test --json '{"name":"demo-user","items":[1,2,3]}'
~/.local/bin/jsonav --test --file data.json
cat data.json | ~/.local/bin/jsonav --test
```

With no input option the command reads stdin until EOF. Use stdin or `--file` for
large/multiline input; shell argument limits still apply to `--json`. Input is
UTF-8, at most 10 MiB. This is a transport bound, not a guarantee that every JSON
shape of that size renders quickly. Very large strings, deep nesting and many
nodes can be expensive in the existing editor/preview. This feature does not
redesign rendering or change existing parser numeric/fragment limitations.

The default target is `local.blingmoon.JSONav.personal`; `--test` selects
`local.blingmoon.JSONav.personal.test`. Preferred locations are `/Applications/JSONav
Personal.app` and `~/Applications/JSONav Personal Test.app`. The command checks
bundle identity and import protocol support before sending. It does not depend on
the default JSON file association and will not send a request to an old app that
lacks this feature. Build locally on each Mac for its native architecture.

## Document behaviour

- Preserve exact text, including whitespace, key order, Unicode, escapes and final
  newline. No automatic formatting or sorting. Tree/structure displays retain
  their existing sorted projection; manually choosing Format still uses the
  existing formatting behaviour.
- Invalid JSON is imported as editable text with an error; old tree nodes are
  cleared. Fixing the text restores normal tree and structure editing.
- Import creates an unsaved Untitled document. Save opens the normal save panel;
  it never writes into the input file or the handoff file.
- Reuse the existing main window, opening/activating it when necessary. The
  process-level receiver retains requests arriving before the view is ready.
- If the current document is unsaved, hold one pending request and ask whether
  to discard current edits and import it. Cancel rejects that request.
- A further arrival asks whether to replace the pending request. It does not
  replace the current document. The incoming request is held only for that
  decision. Further arrivals during the decision are rejected with a notice and
  a nonzero command exit; there is no unbounded queue.

## Delivery and cleanup

The command creates a private unique temporary directory and a binary property-list
`request.jsonav-import` envelope (version, UUID, target app, text, status, message).
It opens this file in the explicitly selected app through NSWorkspace. AppKit file
open events work for both cold launch and an already running process. JSONav reads
and owns the text before acknowledging receipt; sandbox access to the opened file
is retained until the final receipt. No JSON content is logged by the command.

JSONav only updates the explicitly opened handoff file. It never deletes an input
file or writes to a response path embedded by the caller. The creating command
polls the same file, validates its UUID/target, then deletes its own file/directory
only after a terminal response. Buffered status does not mean imported.

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Content was imported into the document (not saved to disk) |
| 1 | Input/app/protocol/delivery failure, or app quit before completion |
| 2 | User cancelled, replaced the pending request, or receiver was busy |
| 3 | Timeout; outcome is unknown and may still complete |

The default timeout is 120 seconds; change it with `--timeout SECONDS`. Timeout
and caller termination do not cancel the app's pending request. The handoff file
is retained and its path is printed on timeout; do not delete it while JSONav may
still need to write its receipt. Once a terminal status is present, retained test
files may be removed. No age-based cleanup races the receiver. An app crash may
leave a nonterminal file; its payload remains recoverable, but automatic resume
and cross-launch deduplication are not provided in this version.

The receipt means the app accepted the text into its document model. It does not
mean the user saved it, nor measure completion of every UI layout operation.

## Acceptance checks

Use only the Test app and disposable data:

1. Quit Test; import `--json` with Chinese, quotes, backslashes and a large integer.
   Confirm window appears and command succeeds.
2. Import stdin containing newlines and invalid JSON. Confirm original text and
   error are visible, tree is empty, and Save requests a destination.
3. With unsaved text, send two commands concurrently. Confirm the second requires
   a buffer replacement decision. Reject/accept it and verify both commands' exit
   statuses. A third command during that decision must return code 2.
4. Close the editor window while Test remains running; import again. Confirm
   window reopens and unsaved content is protected.
5. Test a few-MiB file and compare saved bytes to the input; separately test >10
   MiB rejection, invalid UTF-8, empty input, timeout, and quit while buffered.
6. Verify daily app identity/data are unaffected by `--test`, and that the old
   release is refused by the command until upgraded.
