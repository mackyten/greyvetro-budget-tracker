import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/design_tokens.dart';

/// Mic icon button styled like `_AccountRow`'s existing 28×28 cash-counter
/// button. Starts/stops a `speech_to_text` listen session and reports the
/// final recognized transcript through [onResult] — parsing the words into
/// an amount is the caller's job (`voice_amount_parser.dart`).
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.onResult, this.enabled = true});

  final ValueChanged<String> onResult;
  final bool enabled;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available || !mounted) return;

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        widget.onResult(result.recognizedWords);
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = _listening;
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: active ? AppPalette.error.withValues(alpha: 0.13) : palette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: active ? AppPalette.error : palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.enabled ? _toggleListening : null,
          child: Icon(
            active ? Icons.mic : Icons.mic_none,
            size: 16,
            color: !widget.enabled
                ? palette.muted
                : active
                    ? AppPalette.error
                    : AppPalette.blueDeep,
          ),
        ),
      ),
    );
  }
}
