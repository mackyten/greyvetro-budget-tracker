import 'package:flutter/material.dart';

import 'pin_keypad.dart';
import 'pin_store.dart';

/// Wraps the app: shows a PIN-unlock screen in front of [child] whenever PIN
/// lock is enabled — on cold start, and again any time the app returns to
/// the foreground after being backgrounded, so a picked-up-but-unlocked
/// phone doesn't leave financial data exposed.
class PinGate extends StatefulWidget {
  const PinGate({super.key, required this.child});

  final Widget child;

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> with WidgetsBindingObserver {
  bool _loading = true;
  bool _locked = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshLockState() async {
    final enabled = await PinStore.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _refreshLockState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_locked) {
      return _UnlockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}

class _UnlockScreen extends StatefulWidget {
  const _UnlockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<_UnlockScreen> {
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
        widget.onUnlocked();
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
      title: 'Enter PIN',
      subtitle: 'Unlock Net Worth Tracker',
      enteredLength: _buffer.length,
      errorText: _error,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
    );
  }
}
