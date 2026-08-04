import 'dart:async';

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
  Duration? _lockout;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Lockout state is persisted by PinStore, so a lockout earned before an
    // app restart (or on the unlock gate) must show here too, not just after
    // a failure on this screen.
    _refreshLockout();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final remaining = await PinStore.instance.lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockout = remaining);
    if (remaining != null) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshLockout(),
      );
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_checking || _lockout != null || _buffer.length >= 4) return;
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
        // The failure may have tripped the lockout — pick it up immediately
        // so the countdown starts on this attempt, not the next.
        await _refreshLockout();
      }
    }
  }

  void _onBackspace() {
    if (_buffer.isEmpty || _lockout != null) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return PinKeypad(
      title: widget.title,
      enteredLength: _buffer.length,
      errorText: _lockout != null ? lockoutMessage(_lockout!) : _error,
      enabled: _lockout == null,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      onCancel: () => Navigator.of(context).pop(false),
    );
  }
}

/// Shared countdown copy for both PIN-entry surfaces (this screen and the
/// PinGate unlock screen) so the wording can't drift between them.
String lockoutMessage(Duration remaining) {
  // Ceiling, not floor: showing "0:00" while still locked reads as a bug.
  final seconds = (remaining.inMilliseconds / 1000).ceil();
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return 'Too many attempts — try again in $m:$s';
}
