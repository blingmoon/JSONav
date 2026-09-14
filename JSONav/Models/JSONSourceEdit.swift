import Foundation

struct JSONSourceEdit: Identifiable {
    let id = UUID()
    let source: String
    let range: NSRange
    let replacement: String

    func applying(to current: String) throws -> String {
        guard current == source else { throw JSONFieldError.changedSource }
        return (source as NSString).replacingCharacters(in: range, with: replacement)
    }
}

enum JSONFieldError: LocalizedError {
    case invalidDocument, duplicateKey, missingField, containerValue, invalidValue, changedSource

    var errorDescription: String? {
        switch self {
        case .invalidDocument: return "Fix the JSON in the source editor before editing a field."
        case .duplicateKey: return "Duplicate field names are not supported here. Use a unique name or resolve duplicates in the source editor."
        case .missingField: return "This field no longer exists. Select it again."
        case .containerValue: return "Edit the individual values inside this object or array."
        case .invalidValue: return "Enter a valid value for the selected type."
        case .changedSource: return "The source changed while editing. Select the field again."
        }
    }
}

enum JSONScalarType: String, CaseIterable {
    case string = "String", number = "Number", bool = "Boolean", null = "Null"
}

// Locate tokens in UTF-16, the same coordinate system used by NSTextView.
// Replacing just one token preserves whitespace, ordering and every unrelated number.
struct JSONSourceMap {
    struct Field {
        let path: [String]
        let keyRange: NSRange?
        let valueRange: NSRange
        let scalarType: JSONScalarType?
    }

    let source: String
    private(set) var fields: [[String]: Field] = [:]

    init(_ source: String) throws {
        self.source = source
        // Foundation remains the authority for document validity, not this range scanner.
        guard (try? JSONSerialization.jsonObject(with: Data(source.utf8))) != nil else {
            throw JSONFieldError.invalidDocument
        }
        let text = source as NSString
        var offset = 0
        func skipWhitespace() {
            while offset < text.length && [9, 10, 13, 32].contains(Int(text.character(at: offset))) { offset += 1 }
        }
        func consume(_ code: unichar) throws {
            skipWhitespace()
            guard offset < text.length, text.character(at: offset) == code else { throw JSONFieldError.invalidDocument }
            offset += 1
        }
        func stringRange() throws -> NSRange {
            try consume(34)
            let start = offset - 1
            while offset < text.length {
                let code = text.character(at: offset)
                offset += 1
                if code == 92 { offset += 1 } // Skip escaped characters, including escaped quotes.
                else if code == 34 { return NSRange(location: start, length: offset - start) }
            }
            throw JSONFieldError.invalidDocument
        }
        func scan(path: [String], keyRange: NSRange?) throws {
            skipWhitespace()
            guard offset < text.length else { throw JSONFieldError.invalidDocument }
            let start = offset
            let code = text.character(at: offset)
            let scalar: JSONScalarType?
            switch code {
            case 123, 91: // Object or array; record children before their parent.
                scalar = nil
                offset += 1
                skipWhitespace()
                let close: unichar = code == 123 ? 125 : 93
                var names: Set<String> = []
                var index = 0
                if offset < text.length && text.character(at: offset) != close {
                    while true {
                        let childKey: String
                        let childKeyRange: NSRange?
                        if code == 123 {
                            let range = try stringRange()
                            childKey = try JSONDecoder().decode(String.self, from: Data(text.substring(with: range).utf8))
                            guard names.insert(childKey).inserted else { throw JSONFieldError.duplicateKey }
                            childKeyRange = range
                            try consume(58)
                        } else {
                            childKey = "[\(index)]"
                            childKeyRange = nil
                        }
                        try scan(path: path + [childKey], keyRange: childKeyRange)
                        index += 1
                        skipWhitespace()
                        if offset < text.length && text.character(at: offset) == 44 { offset += 1 }
                        else { break }
                    }
                }
                try consume(close)
            case 34:
                scalar = .string
                _ = try stringRange()
            default:
                scalar = code == 116 || code == 102 ? .bool : (code == 110 ? .null : .number)
                while offset < text.length && ![9, 10, 13, 32, 44, 93, 125].contains(Int(text.character(at: offset))) { offset += 1 }
            }
            fields[path] = Field(path: path, keyRange: keyRange,
                                 valueRange: NSRange(location: start, length: offset - start), scalarType: scalar)
        }
        try scan(path: ["root"], keyRange: nil)
        skipWhitespace()
        guard offset == text.length else { throw JSONFieldError.invalidDocument }
    }

    func edit(path: [String], key: Bool, input: String, type: JSONScalarType) throws -> JSONSourceEdit {
        guard let field = fields[path] else { throw JSONFieldError.missingField }
        let range: NSRange
        let replacement: String
        if key {
            guard let keyRange = field.keyRange else { throw JSONFieldError.missingField }
            let renamedPath = Array(path.dropLast()) + [input]
            guard renamedPath == path || fields[renamedPath] == nil else { throw JSONFieldError.duplicateKey }
            range = keyRange
            replacement = input == path.last ? (source as NSString).substring(with: range) : JSONPreviewDocument.quote(input)
        } else {
            guard field.scalarType != nil else { throw JSONFieldError.containerValue }
            range = field.valueRange
            switch type {
            case .string:
                let oldToken = (source as NSString).substring(with: range)
                let oldText = field.scalarType == .string ? try JSONDecoder().decode(String.self, from: Data(oldToken.utf8)) : nil
                replacement = oldText == input ? oldToken : JSONPreviewDocument.quote(input)
            case .number:
                guard input.range(of: #"\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\z"#,
                                  options: .regularExpression) != nil else { throw JSONFieldError.invalidValue }
                replacement = input
            case .bool:
                guard input == "true" || input == "false" else { throw JSONFieldError.invalidValue }
                replacement = input
            case .null: replacement = "null"
            }
        }
        let edit = JSONSourceEdit(source: source, range: range, replacement: replacement)
        // Validate without reserializing; even exponent spelling must remain untouched.
        _ = try JSONSourceMap(edit.applying(to: source))
        return edit
    }
}
