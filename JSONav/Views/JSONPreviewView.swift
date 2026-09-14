import SwiftUI

struct JSONPreviewView: View {
    let nodes: [JSONNode]
    let errorMessage: String?
    let source: String
    let onEdit: (JSONSourceEdit) throws -> Void
    @State private var searchText = ""
    @State private var expandedPaths: Set<[String]> = [["root"]]
    @State private var selectedMatch: JSONPreviewDocument.Row.ID?
    @State private var editing: JSONFieldDraft?
    @State private var editError: String?

    var body: some View {
        let document = JSONPreviewDocument(nodes: errorMessage == nil ? nodes : [],
                                           expandedPaths: expandedPaths, query: searchText)
        VStack(spacing: 0) {
            HStack {
                Text("Structure Editor").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { expandedPaths = document.containerPaths } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Expand all")
                Button { editing = nil; expandedPaths = [] } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .help("Collapse all")
                .disabled(!searchText.isEmpty)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .frame(height: 33)
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find keys or values…", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { moveMatch(1, in: document.matchIDs) }
                if !searchText.isEmpty {
                    Text("\(document.matchIDs.count)").font(.caption).foregroundStyle(.secondary)
                    Button { moveMatch(-1, in: document.matchIDs) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("Previous match")
                    .disabled(document.matchIDs.isEmpty)
                    Button { moveMatch(1, in: document.matchIDs) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .help("Next match")
                    .disabled(document.matchIDs.isEmpty)
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .help("Clear search")
                }
            }
            .buttonStyle(.borderless)
            .padding(8)
            Divider()
            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Preview unavailable", systemImage: "exclamationmark.triangle")
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if nodes.isEmpty {
                Text("Open a file or enter JSON to preview")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 3) {
                                ForEach(document.rows) { row in
                                    previewRow(row)
                                        .id(row.id)
                                }
                            }
                            .padding(8)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height,
                                   alignment: .topLeading)
                        }
                        .defaultScrollAnchor(.topLeading)
                    }
                    .onChange(of: selectedMatch) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: document.matchIDs, initial: true) { _, ids in
                        selectedMatch = ids.first
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: source) { _, _ in editing = nil }
        .onChange(of: searchText) { _, _ in editing = nil }
        .alert("Could not edit field", isPresented: Binding(
            get: { editError != nil }, set: { if !$0 { editError = nil } }
        )) {
            Button("OK") { editError = nil }
        } message: { Text(editError ?? "") }
    }

    private func previewRow(_ row: JSONPreviewDocument.Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if row.expandable {
                Button {
                    editing = nil
                    if expandedPaths.contains(row.id.path) {
                        expandedPaths.remove(row.id.path)
                    } else {
                        expandedPaths.insert(row.id.path)
                    }
                } label: {
                    Image(systemName: row.expanded ? "minus.circle" : "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(row.expanded ? "Collapse" : "Expand")
                // Matching ancestors stay open until search is cleared.
                .disabled(!searchText.isEmpty)
                .frame(width: 16)
            } else {
                Color.clear.frame(width: 16, height: 1)
            }
            rowText(row)
                .font(.system(size: 13, design: .monospaced))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, CGFloat(row.depth) * 16)
        .padding(.vertical, 1)
        .background(row.matches ? Color.accentColor.opacity(row.id == selectedMatch ? 0.3 : 0.12) : Color.clear)
    }

    private func rowText(_ row: JSONPreviewDocument.Row) -> some View {
        let color: Color
        switch row.value {
        case .string: color = .green
        case .number: color = .blue
        case .bool: color = .orange
        case .null: color = .gray
        case .array, .object: color = .secondary
        }
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let key = row.key {
                if let draft = editing, draft.path == row.id.path, draft.isKey, !row.id.closing {
                    inlineEditor(draft)
                } else {
                    Button { beginEdit(row, key: true) } label: {
                        Text(JSONPreviewDocument.quote(key)).foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("Click to rename this field")
                }
                Text(": ")
            }
            if isScalar(row.value) && !row.id.closing {
                if let draft = editing, draft.path == row.id.path, !draft.isKey {
                    inlineEditor(draft)
                } else {
                    Button { beginEdit(row, key: false) } label: {
                        Text(row.text).foregroundStyle(color)
                    }
                    .buttonStyle(.plain)
                    .help("Click to edit this value")
                }
            } else {
                Text(row.text).foregroundStyle(color)
            }
            Text(row.comma ? "," : "")
        }
    }

    private func inlineEditor(_ draft: JSONFieldDraft) -> some View {
        JSONFieldEditor(draft: draft) { input, type in
            guard source == draft.map.source else { throw JSONFieldError.changedSource }
            let edit = try draft.map.edit(path: draft.path, key: draft.isKey, input: input, type: type)
            try onEdit(edit)
            if draft.isKey {
                // Keep expanded descendants open after renaming their parent key.
                let newPath = Array(draft.path.dropLast()) + [input]
                expandedPaths = Set(expandedPaths.map { path in
                    path.starts(with: draft.path) ? newPath + Array(path.dropFirst(draft.path.count)) : path
                })
            }
            editing = nil
        } onCancel: { editing = nil }
        .id(draft.id)
    }

    private func isScalar(_ value: JSONValue) -> Bool {
        switch value {
        case .object, .array: return false
        default: return true
        }
    }

    private func beginEdit(_ row: JSONPreviewDocument.Row, key: Bool) {
        do { editing = try JSONFieldDraft(source: source, path: row.id.path, isKey: key) }
        catch { editError = error.localizedDescription }
    }

    private func moveMatch(_ offset: Int, in ids: [JSONPreviewDocument.Row.ID]) {
        guard !ids.isEmpty else { return }
        let current = selectedMatch.flatMap { ids.firstIndex(of: $0) } ?? (offset > 0 ? -1 : 0)
        selectedMatch = ids[(current + offset + ids.count) % ids.count]
    }
}
