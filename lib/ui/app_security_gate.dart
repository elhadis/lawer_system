import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../license_service.dart';
import '../security/personal_pin.dart';
import 'activation_screen.dart';
import 'app_shell.dart';
import 'security/set_security_password_screen.dart';
import 'security/unlock_app_screen.dart';

enum _SecurityPhase {
  loading,
  activation,
  setupPin,
  unlock,
  main,
}

/// Orchestrates: **Activation (Layer 1) → PIN setup / unlock (Layer 2) → [AppShell]**.
class AppSecurityGate extends StatefulWidget {
  const AppSecurityGate({super.key});

  static AppSecurityGateState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppSecurityGateState>();

  /// Manual lock from drawer / toolbar.
  static void lock(BuildContext context) {
    maybeOf(context)?.lockSession();
  }

  @override
  State<AppSecurityGate> createState() => AppSecurityGateState();
}

class AppSecurityGateState extends State<AppSecurityGate>
    with WidgetsBindingObserver {
  _SecurityPhase _phase = _SecurityPhase.loading;
  SharedPreferences? _prefs;
  bool _suspendedWhileUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_phase == _SecurityPhase.main) {
        _suspendedWhileUnlocked = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_suspendedWhileUnlocked || !mounted) return;
      _suspendedWhileUnlocked = false;
      final prefs = _prefs;
      if (prefs != null &&
          PersonalPin.hasPin(prefs) &&
          _phase == _SecurityPhase.main) {
        setState(() => _phase = _SecurityPhase.unlock);
      }
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final activated =
        prefs.getBool(LicenseService.prefsKeyIsActivated) ?? false;
    if (!activated) {
      setState(() {
        _prefs = prefs;
        _phase = _SecurityPhase.activation;
      });
      return;
    }
    final hasPin = PersonalPin.hasPin(prefs);
    setState(() {
      _prefs = prefs;
      _phase = hasPin ? _SecurityPhase.unlock : _SecurityPhase.setupPin;
    });
  }

  void _onLicenseActivated() {
    setState(() {
      _phase = _SecurityPhase.setupPin;
    });
  }

  Future<void> _onPinSaved(String pin) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await PersonalPin.saveNewPin(prefs, pin);
    if (!mounted) return;
    setState(() => _phase = _SecurityPhase.main);
  }

  void _onUnlocked() {
    setState(() => _phase = _SecurityPhase.main);
  }

  /// Hide main UI and require PIN again (if configured).
  void lockSession() {
    final prefs = _prefs;
    if (prefs == null || !PersonalPin.hasPin(prefs)) return;
    setState(() {
      _phase = _SecurityPhase.unlock;
      _suspendedWhileUnlocked = false;
    });
  }

  bool _verifyPin(String pin) {
    final prefs = _prefs;
    if (prefs == null) return false;
    return PersonalPin.verify(prefs, pin);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _SecurityPhase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _SecurityPhase.activation:
        return ActivationScreen(onActivated: _onLicenseActivated);
      case _SecurityPhase.setupPin:
        return SetSecurityPasswordScreen(onPinSaved: _onPinSaved);
      case _SecurityPhase.unlock:
        return UnlockAppScreen(
          title: 'تسجيل الدخول',
          subtitle: 'أدخل رمز الأمان المكوّن من 6 أرقام.',
          verifyPin: _verifyPin,
          onUnlocked: _onUnlocked,
        );
      case _SecurityPhase.main:
        return const AppShell();
    }
  }
}
