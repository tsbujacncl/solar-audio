import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// Widget that embeds a VST3 plugin editor GUI
/// Uses platform views to show the native plugin editor
class VST3EditorWidget extends StatefulWidget {
  final int effectId;
  final String pluginName;
  final double width;
  final double height;

  const VST3EditorWidget({
    super.key,
    required this.effectId,
    required this.pluginName,
    required this.width,
    required this.height,
  });

  @override
  State<VST3EditorWidget> createState() => _VST3EditorWidgetState();
}

class _VST3EditorWidgetState extends State<VST3EditorWidget> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return _buildMacOSView();
    } else {
      return _buildUnsupportedPlatform();
    }
  }

  Widget _buildMacOSView() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AppKitView(
        viewType: 'boojy_audio.vst3.editor_view',
        creationParams: {
          'effectId': widget.effectId,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          debugPrint('✅ VST3EditorWidget: Platform view created for effect ${widget.effectId}');
        },
      ),
    );
  }

  Widget _buildUnsupportedPlatform() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF202020),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'VST3 editors not supported on ${Platform.operatingSystem}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
