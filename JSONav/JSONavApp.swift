import SwiftUI

@main
struct JSONEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra {
            Button("Open JSON Editor") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            
            Divider()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "curlybraces")
        }
        
        Window("JSON Editor", id: "main") {
            ContentView(appearanceMode: $appearanceMode)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        // The personal app should open its editor, not only its menu-bar item.
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1300, height: 760)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    NotificationCenter.default.post(name: .newFile, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        JSONImportController.shared.shutdown()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { JSONImportController.shared.receive(url) }
    }
}

extension Notification.Name {
    static let newFile = Notification.Name("newFile")
    static let openFile = Notification.Name("openFile")
    static let openFileURL = Notification.Name("openFileURL")
}
