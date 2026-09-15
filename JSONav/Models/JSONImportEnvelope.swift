import Foundation

/// Shared wire format. The app only rewrites this explicitly opened file, never
/// a caller-supplied response path or an arbitrary neighbouring file.
struct JSONImportEnvelope: Codable {
    static let protocolVersion = 1
    static let maximumTextBytes = 10 * 1024 * 1024
    static let maximumEnvelopeBytes = 32 * 1024 * 1024
    static let fileExtension = "jsonav-import"

    enum Status: String, Codable {
        case submitted, buffered, awaitingReplacement, imported, rejected, replaced, failed
        var isTerminal: Bool {
            switch self {
            case .imported, .rejected, .replaced, .failed: return true
            default: return false
            }
        }
    }

    var version = protocolVersion
    var id: UUID
    var target: String
    var text: String
    var status: Status = .submitted
    var message = ""

    static func read(_ url: URL) throws -> Self {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumEnvelopeBytes + 1) ?? Data()
        guard data.count <= maximumEnvelopeBytes else { throw ImportError("Import file exceeds size limit") }
        let request = try PropertyListDecoder().decode(Self.self, from: data)
        guard request.version == protocolVersion else { throw ImportError("Unsupported import protocol") }
        guard request.text.utf8.count <= maximumTextBytes else { throw ImportError("JSON text exceeds 10 MiB limit") }
        return request
    }

    func write(_ url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

struct ImportError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
