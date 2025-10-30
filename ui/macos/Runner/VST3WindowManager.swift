import Cocoa
import FlutterMacOS

/// Manager for undocked VST3 editor windows
/// Handles creation, lifecycle, and tracking of floating editor windows
class VST3WindowManager {
    static let shared = VST3WindowManager()

    private var windows: [Int: NSWindow] = [:]

    private init() {}

    /// Open a floating window for a VST3 plugin editor
    /// - Parameters:
    ///   - effectId: The effect ID from the audio engine
    ///   - pluginName: Display name for the window title
    ///   - size: Initial window size
    /// - Returns: The created window, or nil if creation failed
    func openWindow(effectId: Int, pluginName: String, size: NSSize) -> NSWindow? {
        // Close existing window if open
        closeWindow(effectId: effectId)

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = pluginName
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0)

        // Create editor view
        let editorView = VST3EditorView(frame: window.contentView!.bounds, effectId: effectId)
        editorView.autoresizingMask = [.width, .height]
        window.contentView = editorView

        // Position window (cascade from main window)
        if let mainWindow = NSApp.mainWindow {
            let cascadePoint = mainWindow.cascadeTopLeft(from: .zero)
            window.setFrameTopLeftPoint(cascadePoint)
        } else {
            window.center()
        }

        // Show window
        window.makeKeyAndOrderFront(nil)

        // Track window
        windows[effectId] = window

        print("✅ VST3WindowManager: Opened floating window for effect \(effectId)")

        return window
    }

    /// Close a floating window
    func closeWindow(effectId: Int) {
        guard let window = windows[effectId] else { return }

        print("🔄 VST3WindowManager: Closing floating window for effect \(effectId)")

        // Remove editor view
        if let editorView = window.contentView as? VST3EditorView {
            editorView.detachEditor()
        }

        window.close()
        windows.removeValue(forKey: effectId)
    }

    /// Close all floating windows
    func closeAllWindows() {
        print("🔄 VST3WindowManager: Closing all floating windows")

        for (_, window) in windows {
            if let editorView = window.contentView as? VST3EditorView {
                editorView.detachEditor()
            }
            window.close()
        }

        windows.removeAll()
    }

    /// Get window for effect ID
    func getWindow(effectId: Int) -> NSWindow? {
        return windows[effectId]
    }

    /// Check if window is open for effect
    func isWindowOpen(effectId: Int) -> Bool {
        return windows[effectId] != nil
    }
}
