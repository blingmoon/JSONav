import AppKit
import Foundation

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let usage = """
Usage: jsonlook [--test] [--timeout SECONDS] [--json TEXT | --file PATH]
Without --json/--file, read UTF-8 text from standard input (maximum 10 MiB).
Default target: JSONLook; --test selects JSONLook Test.
Waits for imported/rejected status. Timeout retains the handoff file and does not cancel.
Exit: 0 imported, 1 failure, 2 rejected/replaced, 3 timeout (outcome unknown).
"""
var useTest = false
var textArgument: String?
var fileArgument: String?
var timeout: Double = 120
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let option = args.removeFirst()
    switch option {
    case "--help", "-h": print(usage); exit(0)
    case "--test": useTest = true
    case "--json", "--file", "--timeout":
        guard !args.isEmpty else { fail("Missing value for \(option)") }
        let value = args.removeFirst()
        if option == "--json" {
            guard textArgument == nil && fileArgument == nil else { fail("Choose one input source") }
            textArgument = value
        } else if option == "--file" {
            guard textArgument == nil && fileArgument == nil else { fail("Choose one input source") }
            fileArgument = value
        } else {
            guard let seconds = Double(value), seconds.isFinite, seconds > 0 else { fail("Invalid timeout") }
            timeout = seconds
        }
    default: fail("Unknown argument: \(option)\n\(usage)")
    }
}

do {
    let identifier = "local.blingmoon.JSONav.personal" + (useTest ? ".test" : "")
    let preferred = useTest
        ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/JSONLook Test.app")
        : URL(fileURLWithPath: "/Applications/JSONLook.app")
    let appURL: URL
    if FileManager.default.fileExists(atPath: preferred.path) {
        appURL = preferred
    } else if let located = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
        appURL = located
    } else { throw ImportError("Install \(useTest ? "JSONLook Test" : "JSONLook") first") }
    guard let bundle = Bundle(url: appURL), bundle.bundleIdentifier == identifier,
          bundle.object(forInfoDictionaryKey: "JSONavImportProtocolVersion") as? Int == JSONImportEnvelope.protocolVersion
    else { throw ImportError("Selected app does not support this import protocol. Update it first: \(appURL.path)") }

    let text: String
    if let textArgument {
        text = textArgument
    } else {
        if fileArgument == nil && isatty(STDIN_FILENO) != 0 { fail(usage) }
        let input = try fileArgument.map { try FileHandle(forReadingFrom: URL(fileURLWithPath: $0)) }
            ?? FileHandle.standardInput
        defer { if fileArgument != nil { try? input.close() } }
        // Pipes can return short reads: accumulate until EOF, with a hard memory bound.
        var bytes = Data()
        while let chunk = try input.read(upToCount: min(65536, JSONImportEnvelope.maximumTextBytes + 1 - bytes.count)), !chunk.isEmpty {
            bytes.append(chunk)
            if bytes.count > JSONImportEnvelope.maximumTextBytes { throw ImportError("Input exceeds 10 MiB limit") }
        }
        guard let decoded = String(data: bytes, encoding: .utf8) else { throw ImportError("Input must be valid UTF-8") }
        text = decoded
    }
    guard text.utf8.count <= JSONImportEnvelope.maximumTextBytes else { throw ImportError("Input exceeds 10 MiB limit") }
    let request = JSONImportEnvelope(id: UUID(), target: identifier, text: text)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("jsonlook-\(request.id.uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                            attributes: [.posixPermissions: 0o700])
    let url = directory.appendingPathComponent("request.jsonav-import")
    try request.write(url)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    var openingComplete = false
    var openingError: Error?
    NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
        openingError = error
        openingComplete = true
    }
    let deadline = Date().addingTimeInterval(timeout)
    var lastStatus: JSONImportEnvelope.Status?
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        if openingComplete, let openingError {
            throw ImportError("Could not deliver request: \(openingError.localizedDescription). Retained: \(url.path)")
        }
        guard let response = try? JSONImportEnvelope.read(url), response.id == request.id,
              response.target == request.target else { continue }
        if response.status != lastStatus {
            lastStatus = response.status
            FileHandle.standardError.write(Data((response.message.isEmpty ? "Submitting import…\n" : response.message + "\n").utf8))
        }
        if response.status.isTerminal {
            // Only the creating command cleans up, and only after the app's terminal receipt.
            do {
                try FileManager.default.removeItem(at: url)
                try FileManager.default.removeItem(at: directory)
            } catch {
                FileHandle.standardError.write(Data("Cleanup warning: \(error.localizedDescription); directory: \(directory.path)\n".utf8))
            }
            if response.status == .imported { print("Imported"); exit(0) }
            fail(response.message, code: response.status == .failed ? 1 : 2)
        }
    }
    fail("Timed out; import may still complete. Do not immediately retry or delete the file. Retained: \(url.path)", code: 3)
} catch { fail(error.localizedDescription) }
