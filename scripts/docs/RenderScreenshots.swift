import SwiftUI
import AppKit

// A separate documentation process renders production views with synthetic data.
// It never opens files in the installed Personal/Test apps or changes their defaults.
extension Notification.Name {
    static let newFile = Notification.Name("newFile")
    static let openFile = Notification.Name("openFile")
    static let openFileURL = Notification.Name("openFileURL")
}

@main
struct RenderScreenshots {
    static func capture<V: View>(_ root: V, size: NSSize, name: String,
                                 prepare: () -> Void = {}) throws {
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        prepare()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ImportError("Could not capture documentation view")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: URL(fileURLWithPath: "docs/screenshots/\(name).png"))
        window.close()
    }

    static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let suite = "JSONav.docs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "showTreeSidebar")
        defaults.set(true, forKey: "showStructureEditor")
        defer { defaults.removePersistentDomain(forName: suite) }
        let source = """
        {
          "name": "demo-user",
          "task_id": 254136,
          "enabled": true,
          "project": {
            "name": "个人 JSON 工具",
            "id": 9007199254740993
          },
          "items": [1, 2, 3],
          "message": "中文示例"
        }
        """
        for (name, mode, color) in [("personal-light", AppearanceMode.light, ColorScheme.light),
                                    ("personal-dark", AppearanceMode.dark, ColorScheme.dark)] {
            try capture(ContentView(appearanceMode: .constant(mode))
                .background(.background).defaultAppStorage(defaults).preferredColorScheme(color),
                size: NSSize(width: 1280, height: 340), name: name) {
                JSONImportController.shared.importText?(source)
            }
        }
        try capture(ContentView(appearanceMode: .constant(.light))
            .background(.background).defaultAppStorage(defaults).preferredColorScheme(.light),
            size: NSSize(width: 1280, height: 280), name: "personal-invalid") {
            JSONImportController.shared.importText?("{\n  \"name\": \"demo-user\",\n  \"items\": [1, 2,\n}\n")
        }
        let draft = try JSONFieldDraft(source: source, path: ["root", "task_id"], isKey: false)
        try capture(HStack {
            Text("\"task_id\": ").foregroundStyle(.purple)
            JSONFieldEditor(draft: draft, onSave: { _, _ in }, onCancel: {})
            Text(",")
        }.font(.system(size: 13, design: .monospaced)).padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.background).preferredColorScheme(.light),
            size: NSSize(width: 490, height: 72), name: "personal-inline")
        print("Documentation view captures generated")
    }
}
