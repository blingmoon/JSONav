import SwiftUI

struct JSONImportPrompt: View {
    @ObservedObject var imports: JSONImportController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if imports.replacement != nil {
                Text("Import buffer is full").font(.headline)
                Text("Replace the pending import with the new request? Your current document will not change.")
                HStack {
                    Button("Keep Pending Import") { imports.resolveReplacement(accept: false) }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Replace Pending Import") { imports.resolveReplacement(accept: true) }
                }
            } else {
                Text("Unsaved Changes").font(.headline)
                Text("Importing will replace your current document. Cancel to keep your edits, or discard them and import.")
                HStack {
                    Button("Cancel Import") { imports.rejectImport() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Discard Changes and Import", role: .destructive) { imports.acceptImport() }
                }
            }
            if let notice = imports.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(20)
        .frame(width: 440)
        .interactiveDismissDisabled()
    }
}
