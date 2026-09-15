import SwiftUI
import AppKit
import Combine

/// Owns deliveries independently of a view's lifetime so cold-start events are
/// retained. One pending request plus one replacement decision, never a queue.
@MainActor
final class JSONImportController: ObservableObject {
    static let shared = JSONImportController()

    struct Delivery {
        var envelope: JSONImportEnvelope
        let url: URL
        let scoped: Bool
    }

    @Published private(set) var pending: Delivery?
    @Published private(set) var replacement: Delivery?
    @Published var notice: String?
    @Published var failure: String?
    var wakeWindow: (() -> Void)?
    var canImport: (() -> Bool)?
    var importText: ((String) -> Void)?
    var ordinaryFile: ((URL) -> Void)?
    private var earlyFile: URL?
    private let targetIdentifier: String?

    init(targetIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.targetIdentifier = targetIdentifier
    }

    var needsDecision: Bool { pending != nil && importText != nil }

    func receive(_ url: URL) {
        wakeWindow?()
        NSApp.activate(ignoringOtherApps: true)
        guard url.pathExtension == JSONImportEnvelope.fileExtension else {
            if pending != nil || earlyFile != nil {
                failure = "Another open/import request is pending. Please retry this file after resolving it."
            } else if let ordinaryFile {
                ordinaryFile(url)
            } else {
                earlyFile = url
            }
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        do {
            let request = try JSONImportEnvelope.read(url)
            guard request.target == targetIdentifier else {
                throw ImportError("This request targets a different JSONav app")
            }
            // Re-delivery of the same opened file must not import it twice.
            guard request.status == .submitted else {
                if scoped { url.stopAccessingSecurityScopedResource() }
                return
            }
            let incoming = Delivery(envelope: request, url: url, scoped: scoped)
            if replacement != nil {
                finish(incoming, as: .rejected, message: "A buffer replacement decision is already pending")
                notice = "Another import was rejected while you were choosing whether to replace the buffer."
            } else if pending != nil {
                replacement = incoming
                acknowledgeReplacement()
            } else {
                pending = incoming
                acknowledgePending()
                processIfReady()
            }
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            failure = "Could not receive import: \(error.localizedDescription)"
        }
    }

    func viewReady() {
        if let url = earlyFile, let ordinaryFile {
            earlyFile = nil
            ordinaryFile(url)
        }
        processIfReady()
    }

    func processIfReady() {
        guard replacement == nil, let pending, let importText, canImport?() == true else { return }
        self.pending = nil
        importText(pending.envelope.text)
        finish(pending, as: .imported, message: "Imported into an unsaved document")
    }

    func acceptImport() {
        guard replacement == nil, let pending, let importText else { return }
        self.pending = nil
        notice = nil
        importText(pending.envelope.text)
        finish(pending, as: .imported, message: "Imported into an unsaved document")
    }

    func rejectImport() {
        guard replacement == nil, let pending else { return }
        self.pending = nil
        notice = nil
        finish(pending, as: .rejected, message: "Import cancelled by user")
    }

    func resolveReplacement(accept: Bool) {
        guard let replacement else { return }
        self.replacement = nil
        if accept {
            if let pending { finish(pending, as: .replaced, message: "Pending import replaced by user") }
            pending = replacement
            acknowledgePending()
        } else {
            finish(replacement, as: .rejected, message: "User kept the existing pending import")
        }
        notice = nil
        processIfReady()
    }

    func shutdown() {
        if let replacement { finish(replacement, as: .failed, message: "JSONav quit before resolving this request") }
        if let pending { finish(pending, as: .failed, message: "JSONav quit before importing this request") }
        replacement = nil
        pending = nil
    }

    private func acknowledgePending() {
        guard var delivery = pending else { return }
        delivery.envelope.status = .buffered
        delivery.envelope.message = "Received; waiting for the editor or user confirmation"
        pending = delivery
        writeReceipt(delivery)
    }

    private func acknowledgeReplacement() {
        guard var delivery = replacement else { return }
        delivery.envelope.status = .awaitingReplacement
        delivery.envelope.message = "Waiting for permission to replace the pending import"
        replacement = delivery
        writeReceipt(delivery)
    }

    private func finish(_ request: Delivery, as status: JSONImportEnvelope.Status, message: String) {
        var result = request
        result.envelope.status = status
        result.envelope.message = message
        writeReceipt(result)
        if request.scoped { request.url.stopAccessingSecurityScopedResource() }
    }

    private func writeReceipt(_ delivery: Delivery) {
        do { try delivery.envelope.write(delivery.url) }
        catch {
            failure = "Import status could not be written. The calling command may time out: \(error.localizedDescription)"
        }
    }
}
