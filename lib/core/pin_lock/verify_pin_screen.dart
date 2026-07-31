import 'package:flutter/material.dart';

import 'pin_keypad.dart';
import 'pin_store.dart';

/// Verifies the currently-set PIN before a sensitive Settings action
/// (disabling PIN lock, or changing the PIN) — pops `true` once correct,
/// or `null`/`false` if cancelled.
class VerifyPinScreen extends StatefulWidget {
  const VerifyPinScreen({super.key, this.title = 'Enter current PIN'});

  final String title;

  @override
  State<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<VerifyPinScreen> {
  String _buffer = '';
  String? _error;
  bool _checking = false;

  Future<void> _onDigit(String digit) async {
    if (_checking || _buffer.length >= 4) return;
    setState(() {
      _buffer += digit;
      _error = null;
    });
    if (_buffer.length == 4) {
      setState(() => _checking = true);
      final ok = await PinStore.instance.verify(_buffer);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _buffer = '';
          _error = 'Incorrect PIN';
          _checking = false;
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
      title: widget.title,
      enteredLength: _buffer.length,
      errorText: _error,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      onCancel: () => Navigator.of(context).pop(false),
    );
  }
}
