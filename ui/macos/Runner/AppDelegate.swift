import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var vst3PlatformChannel: VST3PlatformChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Register VST3 platform integration immediately (lightweight, won't block UI)
    setupVST3Platform()
  }

  private func setupVST3Platform() {
    // Get the Flutter view controller
    guard let mainFlutterWindow = NSApp.windows.first,
          let flutterViewController = mainFlutterWindow.contentViewController as? FlutterViewController else {
      print("❌ AppDelegate: Could not find Flutter view controller")
      return
    }

    let messenger = flutterViewController.engine.binaryMessenger

    // Register VST3 platform view factory (M7 Phase 2)
    let vst3Factory = VST3PlatformViewFactory(messenger: messenger)
    flutterViewController.engine.registrar(forPlugin: "VST3PlatformView")
      .register(vst3Factory, withId: "solar_audio.vst3.editor_view")

    // Initialize VST3 platform channel (M7 Phase 2)
    vst3PlatformChannel = VST3PlatformChannel(messenger: messenger)

    print("✅ AppDelegate: VST3 platform integration initialized")
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    // Clean up all VST3 editor windows
    VST3WindowManager.shared.closeAllWindows()
    super.applicationWillTerminate(notification)
  }
}
