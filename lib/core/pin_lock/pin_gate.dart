import 'dart:async';

import 'package:flutter/material.dart';

import 'biometric_auth.dart';
import 'pin_keypad.dart';
import 'pin_store.dart';
import 'verify_pin_screen.dart' show lockoutMessage;

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
  bool _biometricEnabled = false;
  Duration? _lockout;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    // Lockout survives app restarts (persisted by PinStore), so the gate
    // must reflect one immediately on cold start — otherwise killing the
    // app would visually reset the countdown.
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

  Future<void> _loadBiometricState() async {
    final enabled = await PinStore.instance.isBiometricEnabled();
    final available = await BiometricAuth.instance.isAvailable();
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled && available);
  }

  Future<void> _onBiometricTap() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await BiometricAuth.instance.authenticate(
      reason: 'Unlock Net Worth Tracker',
    );
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _checking = false);
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
        widget.onUnlocked();
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
      title: 'Enter PIN',
      subtitle: 'Unlock Net Worth Tracker',
      enteredLength: _buffer.length,
      errorText: _lockout != null ? lockoutMessage(_lockout!) : _error,
      // Keypad locks during the countdown; the biometric shortcut stays
      // usable (see PinKeypad.enabled) since it isn't a guessable channel.
      enabled: _lockout == null,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      onBiometricTap: _biometricEnabled ? _onBiometricTap : null,
    );
  }
}
