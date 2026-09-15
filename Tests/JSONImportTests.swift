import AppKit
import Foundation

@main
struct JSONImportTests {
    static func main() throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func check(_ condition: Bool) { assert(condition) }
        let target = "test.import"
        func request(_ text: String) throws -> URL {
            let id = UUID()
            let url = folder.appendingPathComponent("\(id).jsonav-import")
            try JSONImportEnvelope(id: id, target: target, text: text).write(url)
            return url
        }
        func status(_ url: URL) throws -> JSONImportEnvelope.Status { try JSONImportEnvelope.read(url).status }
        let controller = JSONImportController(targetIdentifier: target)
        var received: [String] = []
        var dirty = false
        let original = "{\n  \"中文😀\": \"space \\\" quote \\\\ slash\",\n  \"big\": 9007199254740993\n}\n"
        let cold = try request(original)
        controller.receive(cold)
        check(try status(cold) == .buffered)
        assert(received.isEmpty)
        controller.canImport = { !dirty }
        controller.importText = { received.append($0); dirty = true }
        controller.viewReady()
        assert(received == [original])
        check(try status(cold) == .imported)
        controller.receive(cold)
        assert(received.count == 1)

        let first = try request("first"), second = try request("second"), third = try request("third")
        controller.receive(first)
        controller.receive(second)
        check(try status(first) == .buffered)
        check(try status(second) == .awaitingReplacement)
        controller.receive(third)
        check(try status(third) == .rejected)
        assert(received == [original])
        controller.resolveReplacement(accept: false)
        check(try status(second) == .rejected)
        assert(controller.pending?.envelope.text == "first")
        let replacement = try request("{ invalid JSON")
        controller.receive(replacement)
        controller.resolveReplacement(accept: true)
        check(try status(first) == .replaced)
        check(try status(replacement) == .buffered)
        assert(received == [original]) // Buffer replacement does not edit the document.
        controller.acceptImport()
        assert(received.last == "{ invalid JSON")
        check(try status(replacement) == .imported)
        let cancel = try request("cancel")
        controller.receive(cancel)
        controller.rejectImport()
        check(try status(cancel) == .rejected)
        assert(received.count == 2)

        let quit = try request("quit")
        controller.receive(quit)
        controller.shutdown()
        check(try status(quit) == .failed)
        assert(controller.pending == nil && controller.replacement == nil)

        let largeText = String(repeating: "中文😀\n", count: 400_000)
        let large = try request(largeText)
        check(try JSONImportEnvelope.read(large).text == largeText)
        let oversized = try request(String(repeating: "x", count: JSONImportEnvelope.maximumTextBytes + 1))
        do {
            _ = try JSONImportEnvelope.read(oversized)
            fatalError("Oversized input should fail")
        } catch is ImportError { }
        print("Import cold-start buffering, single-slot decisions, exact text and size regressions passed")
    }
}
