import Cocoa
import FlutterMacOS

/// NSView wrapper for VST3 plugin editors
/// This view holds the native VST3 editor GUI and manages its lifecycle
class VST3EditorView: NSView {
    private var editorView: NSView?
    private var effectId: Int = -1

    init(frame: NSRect, effectId: Int) {
        self.effectId = effectId
        super.init(frame: frame)

        // Dark background for consistency
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Attach a native VST3 editor view
    func attachEditor(view: NSView) {
        // Remove existing editor if any
        detachEditor()

        // Add the new editor view
        editorView = view
        addSubview(view)

        // Position the editor view
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
    }

    /// Detach and remove the current editor view
    func detachEditor() {
        editorView?.removeFromSuperview()
        editorView = nil
    }

    deinit {
        detachEditor()
    }
}

/// Flutter platform view factory for VST3 editors
class VST3PlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        guard let args = args as? [String: Any],
              let effectId = args["effectId"] as? Int else {
            print("❌ VST3PlatformView: Missing effectId argument")
            return NSView()
        }

        print("✅ VST3PlatformView: Creating view for effect \(effectId)")

        // Create the editor view
        let editorView = VST3EditorView(frame: .zero, effectId: effectId)

        // TODO: Request the native editor from the audio engine
        // This will be handled through platform channels

        return editorView
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
