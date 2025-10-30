import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing VST3 plugin editor windows
/// Communicates with native platform code to show/hide editor GUIs
class VST3EditorService {
  static const _channel = MethodChannel('solar_audio.vst3.editor');

  /// Open a floating (undocked) editor window for a VST3 plugin
  ///
  /// Parameters:
  /// - effectId: The effect ID from the audio engine
  /// - pluginName: Display name for the window title
  /// - width: Window width in pixels
  /// - height: Window height in pixels
  static Future<bool> openFloatingWindow({
    required int effectId,
    required String pluginName,
    required double width,
    required double height,
  }) async {
    try {
      final result = await _channel.invokeMethod('openFloatingWindow', {
        'effectId': effectId,
        'pluginName': pluginName,
        'width': width,
        'height': height,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ VST3EditorService: Failed to open floating window: $e');
      return false;
    }
  }

  /// Close a floating editor window
  static Future<bool> closeFloatingWindow({
    required int effectId,
  }) async {
    try {
      final result = await _channel.invokeMethod('closeFloatingWindow', {
        'effectId': effectId,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ VST3EditorService: Failed to close floating window: $e');
      return false;
    }
  }

  /// Attach a VST3 editor to a docked platform view
  static Future<bool> attachEditor({
    required int effectId,
  }) async {
    try {
      final result = await _channel.invokeMethod('attachEditor', {
        'effectId': effectId,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ VST3EditorService: Failed to attach editor: $e');
      return false;
    }
  }

  /// Detach a VST3 editor from a platform view
  static Future<bool> detachEditor({
    required int effectId,
  }) async {
    try {
      final result = await _channel.invokeMethod('detachEditor', {
        'effectId': effectId,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ VST3EditorService: Failed to detach editor: $e');
      return false;
    }
  }
}
