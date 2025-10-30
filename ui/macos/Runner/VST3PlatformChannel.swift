import Cocoa
import FlutterMacOS

/// Platform channel for VST3 editor communication
/// Handles method calls from Flutter to manage VST3 editor windows
class VST3PlatformChannel {
    static let channelName = "solar_audio.vst3.editor"

    private var channel: FlutterMethodChannel
    private var windowManager = VST3WindowManager.shared

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: VST3PlatformChannel.channelName,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }

        print("✅ VST3PlatformChannel: Initialized")
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let args = call.arguments as? [String: Any] ?? [:]

        switch method {
        case "openFloatingWindow":
            openFloatingWindow(args: args, result: result)

        case "closeFloatingWindow":
            closeFloatingWindow(args: args, result: result)

        case "attachEditor":
            attachEditor(args: args, result: result)

        case "detachEditor":
            detachEditor(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Open a floating (undocked) editor window
    private func openFloatingWindow(args: [String: Any], result: @escaping FlutterResult) {
        guard let effectId = args["effectId"] as? Int,
              let pluginName = args["pluginName"] as? String,
              let width = args["width"] as? Double,
              let height = args["height"] as? Double else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments: effectId, pluginName, width, height",
                details: nil
            ))
            return
        }

        let size = NSSize(width: width, height: height)

        if windowManager.openWindow(effectId: effectId, pluginName: pluginName, size: size) != nil {
            // TODO: Call Rust FFI to attach the native VST3 editor view
            // For now, just return success
            result(true)
        } else {
            result(FlutterError(
                code: "WINDOW_CREATION_FAILED",
                message: "Failed to create window for effect \(effectId)",
                details: nil
            ))
        }
    }

    /// Close a floating editor window
    private func closeFloatingWindow(args: [String: Any], result: @escaping FlutterResult) {
        guard let effectId = args["effectId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: effectId",
                details: nil
            ))
            return
        }

        windowManager.closeWindow(effectId: effectId)
        result(true)
    }

    /// Attach a VST3 editor to a docked platform view
    private func attachEditor(args: [String: Any], result: @escaping FlutterResult) {
        guard let effectId = args["effectId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: effectId",
                details: nil
            ))
            return
        }

        // TODO: Implement attaching editor to embedded platform view
        // This will require finding the platform view and calling attachEditor on it
        print("📎 VST3PlatformChannel: Attach editor for effect \(effectId)")
        result(true)
    }

    /// Detach a VST3 editor from a platform view
    private func detachEditor(args: [String: Any], result: @escaping FlutterResult) {
        guard let effectId = args["effectId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required argument: effectId",
                details: nil
            ))
            return
        }

        // TODO: Implement detaching editor from embedded platform view
        print("📎 VST3PlatformChannel: Detach editor for effect \(effectId)")
        result(true)
    }
}
