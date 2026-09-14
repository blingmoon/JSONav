import SwiftUI

struct JSONFieldDraft: Identifiable {
    let id = UUID()
    let map: JSONSourceMap
    let path: [String]
    let isKey: Bool
    let input: String
    let type: JSONScalarType

    init(source: String, path: [String], isKey: Bool) throws {
        map = try JSONSourceMap(source)
        self.path = path
        self.isKey = isKey
        guard let field = map.fields[path] else { throw JSONFieldError.missingField }
        let range: NSRange
        if isKey {
            guard let keyRange = field.keyRange else { throw JSONFieldError.missingField }
            range = keyRange
            type = .string
        } else {
            guard let scalarType = field.scalarType else { throw JSONFieldError.containerValue }
            range = field.valueRange
            type = scalarType
        }
        let token = (source as NSString).substring(with: range)
        // Use the original token, not NSNumber's normalized display, to seed the edit.
        input = type == .string ? try JSONDecoder().decode(String.self, from: Data(token.utf8)) : token
    }
}

struct JSONFieldEditor: View {
    let draft: JSONFieldDraft
    let onSave: (String, JSONScalarType) throws -> Void
    let onCancel: () -> Void
    @State private var input: String
    @State private var type: JSONScalarType
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(draft: JSONFieldDraft, onSave: @escaping (String, JSONScalarType) throws -> Void,
         onCancel: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
        _input = State(initialValue: draft.input)
        _type = State(initialValue: draft.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField(draft.isKey ? "Field name" : "Value", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: inputWidth)
                    .focused($focused)
                    .onSubmit(save)
                    .help(type == .string ? "Text without surrounding quotes; Return to apply, Escape to cancel" : "Return to apply, Escape to cancel")
                if !draft.isKey {
                    Picker("Type", selection: $type) {
                        ForEach(JSONScalarType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 85)
                    .onChange(of: type) { _, newType in
                        errorMessage = nil
                        if newType == .bool && input != "true" && input != "false" { input = "false" }
                        if newType == .null { input = "null" }
                    }
                }
                Button(action: save) { Image(systemName: "checkmark") }
                    .help("Apply (Return)")
                Button(action: onCancel) { Image(systemName: "xmark") }
                    .help("Cancel (Escape)")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .frame(width: inputWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onExitCommand(perform: onCancel)
        .onAppear { focused = true }
    }

    private var inputWidth: CGFloat {
        // The preview scrolls horizontally, so give its inline input a finite width.
        let width = (input as NSString).size(withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]).width
        return min(480, max(90, width + 24))
    }

    private func save() {
        do { try onSave(input, type) }
        catch { errorMessage = error.localizedDescription }
    }
}
