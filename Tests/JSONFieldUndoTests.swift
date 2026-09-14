import SwiftUI
import AppKit

@main
struct JSONFieldUndoTests {
    static func main() throws {
        _ = NSApplication.shared
        let source = #"{"😀":"中文","task_id":254136,"big":9007199254740993}"#
        var raw = source
        var changes = 0
        let wrapper = SyntaxHighlightingTextView(
            text: Binding(get: { raw }, set: { raw = $0 }), isValid: .constant(true),
            navigateToPath: .constant(nil), currentCursorPath: .constant([]),
            pendingFieldEdit: .constant(nil), fieldEditError: .constant(nil),
            onTextChange: { _ in changes += 1 })
        let coordinator = wrapper.makeCoordinator()
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.string = source
        textView.delegate = coordinator
        coordinator.textView = textView
        guard let undo = textView.undoManager else { fatalError("Expected editor undo manager") }
        undo.groupsByEvent = false
        undo.removeAllActions()
        let edit = try JSONSourceMap(source).edit(path: ["root", "task_id"], key: false, input: "254137", type: .number)
        let updated = try edit.applying(to: source)
        undo.beginUndoGrouping()
        try SyntaxHighlightingTextView.applyFieldEdit(edit, to: textView)
        undo.endUndoGrouping()
        precondition(raw == updated && textView.string == updated && changes == 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        precondition(undo.canUndo)
        undo.undo()
        precondition(raw == source && textView.string == source)
        undo.redo()
        precondition(raw == updated && textView.string == updated)
        do {
            try SyntaxHighlightingTextView.applyFieldEdit(edit, to: textView)
            fatalError("Stale edits must not overwrite text")
        } catch JSONFieldError.changedSource { }
        precondition(raw == updated)
        coordinator.highlightTask?.cancel()
        coordinator.cursorUpdateTask?.cancel()
        window.close()
        print("JSON field edit / undo / redo integration passed")
    }
}
