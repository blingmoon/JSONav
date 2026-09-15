import AppKit
import SwiftUI

extension Notification.Name {
  static let newFile = Notification.Name("newFile")
  static let openFile = Notification.Name("openFile")
  static let openFileURL = Notification.Name("openFileURL")
}
@main struct JSONImportViewTests {
  static func main() throws {
    NSApplication.shared.setActivationPolicy(.accessory)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1300, height: 600), styleMask: [.titled],
      backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: ContentView(appearanceMode: .constant(.light)))
    window.orderFront(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    let imports = JSONImportController.shared
    imports.wakeWindow = nil
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    func send(_ text: String) throws -> URL {
      let url = dir.appendingPathComponent(UUID().uuidString + ".jsonav-import")
      try JSONImportEnvelope(id: UUID(), target: Bundle.main.bundleIdentifier!, text: text).write(
        url)
      imports.receive(url)
      RunLoop.main.run(until: Date().addingTimeInterval(0.3))
      return url
    }
    let first = try send("{\"one\":1}")
    assert(tryStatus(first) == .imported)
    assert(imports.canImport?() == false)
    let second = try send("{\"two\":2}")
    assert(tryStatus(second) == .buffered)
    imports.acceptImport()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    assert(imports.canImport?() == false)
    let third = try send("{\"three\":3}")
    assert(tryStatus(third) == .buffered)
    imports.rejectImport()
    print("Real ContentView dirty guard stays active across repeated imports")
    window.close()
  }
  static func tryStatus(_ url: URL) -> JSONImportEnvelope.Status {
    try! JSONImportEnvelope.read(url).status
  }
}
