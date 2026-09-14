import Foundation

// Display-only rows: collapsing never replaces text in the editor or saved JSON.
struct JSONPreviewDocument {
    struct Row: Identifiable {
        struct ID: Hashable {
            let path: [String]
            let closing: Bool
        }
        let id: ID
        let depth: Int
        let key: String?
        let text: String
        let value: JSONValue
        let expandable: Bool
        let expanded: Bool
        let comma: Bool
        let matches: Bool
    }

    var rows: [Row] = []
    var containerPaths: Set<[String]> = []
    var matchIDs: [Row.ID] { rows.filter(\.matches).map(\.id) }

    init(nodes: [JSONNode], expandedPaths: Set<[String]>, query: String) {
        var matchingPaths: Set<[String]> = []
        var matchingBranches: Set<[String]> = []
        func index(_ node: JSONNode, showKey: Bool) {
            if !node.children.isEmpty { containerPaths.insert(node.path) }
            let valueText: String
            switch node.value {
            case .string(let text): valueText = text
            case .number(let number): valueText = number.stringValue
            case .bool(let value): valueText = value ? "true" : "false"
            case .null: valueText = "null"
            case .array, .object: valueText = ""
            }
            // Synthetic root/array labels are not JSON keys.
            let key = showKey ? (node.key ?? "") : ""
            if !query.isEmpty && (key.localizedCaseInsensitiveContains(query)
                || valueText.localizedCaseInsensitiveContains(query)) {
                matchingPaths.insert(node.path)
                for length in 1...node.path.count {
                    matchingBranches.insert(Array(node.path.prefix(length)))
                }
            }
            let childrenHaveKeys: Bool
            if case .object = node.value { childrenHaveKeys = true } else { childrenHaveKeys = false }
            node.children.forEach { index($0, showKey: childrenHaveKeys) }
        }
        nodes.forEach { index($0, showKey: false) }

        func append(_ node: JSONNode, depth: Int, showKey: Bool, comma: Bool) {
            let expandable = !node.children.isEmpty
            let expanded = expandable && (expandedPaths.contains(node.path) || matchingBranches.contains(node.path))
            let text: String
            let closing: String?
            let childrenHaveKeys: Bool
            switch node.value {
            case .object:
                text = expandable ? (expanded ? "{" : "{…}") : "{}"
                closing = "}"
                childrenHaveKeys = true
            case .array:
                text = expandable ? (expanded ? "[" : "[…]") : "[]"
                closing = "]"
                childrenHaveKeys = false
            case .string(let value):
                text = Self.quote(value)
                closing = nil
                childrenHaveKeys = false
            default:
                text = node.displayValue
                closing = nil
                childrenHaveKeys = false
            }
            rows.append(Row(id: .init(path: node.path, closing: false), depth: depth,
                            key: showKey ? node.key : nil, text: text, value: node.value,
                            expandable: expandable, expanded: expanded,
                            comma: comma && !expanded, matches: matchingPaths.contains(node.path)))
            if expanded, let closing {
                for (index, child) in node.children.enumerated() {
                    append(child, depth: depth + 1, showKey: childrenHaveKeys,
                           comma: index < node.children.count - 1)
                }
                rows.append(Row(id: .init(path: node.path, closing: true), depth: depth,
                                key: nil, text: closing, value: node.value,
                                expandable: false, expanded: false, comma: comma, matches: false))
            }
        }
        nodes.forEach { append($0, depth: 0, showKey: false, comma: false) }
    }

    static func quote(_ value: String) -> String {
        // Preserve string boundaries, including embedded quotes, newlines and backslashes.
        let data = try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}
