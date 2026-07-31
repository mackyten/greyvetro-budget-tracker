import 'package:flutter/material.dart';

import 'pin_keypad.dart';

/// Two-step "enter, then confirm" PIN creation — pops with the new PIN
/// string once both entries match, or with `null` if cancelled.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String? _firstEntry;
  String _buffer = '';
  String? _error;

  bool get _confirming => _firstEntry != null;

  void _onDigit(String digit) {
    if (_buffer.length >= 4) return;
    setState(() {
      _buffer += digit;
      _error = null;
    });
    if (_buffer.length == 4) {
      if (!_confirming) {
        setState(() {
          _firstEntry = _buffer;
          _buffer = '';
        });
      } else if (_buffer == _firstEntry) {
        Navigator.of(context).pop(_buffer);
      } else {
        setState(() {
          _firstEntry = null;
          _buffer = '';
          _error = "PINs didn't match — try again";
        });
      }
    }
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return PinKeypad(
      title: _confirming ? 'Confirm PIN' : 'Create a PIN',
      subtitle: _confirming
          ? 'Enter it once more to confirm'
          : "You'll use this to unlock the app",
      enteredLength: _buffer.length,
      errorText: _error,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      onCancel: () => Navigator.of(context).pop(),
    );
  }
}
