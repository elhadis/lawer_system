import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'security_auth_layout.dart';

/// Returning user: enter PIN after launch, resume, or manual lock.
class UnlockAppScreen extends StatefulWidget {
  const UnlockAppScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.verifyPin,
    required this.onUnlocked,
  });

  final String title;
  final String? subtitle;
  final bool Function(String pin6) verifyPin;
  final VoidCallback onUnlocked;

  @override
  State<UnlockAppScreen> createState() => _UnlockAppScreenState();
}

class _UnlockAppScreenState extends State<UnlockAppScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  static final _digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _pin.text.trim();
    if (p.length != 6) {
      setState(() => _error = 'أدخل الرمز المكوّن من 6 أرقام.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = widget.verifyPin(p);
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'الرمز غير صحيح.';
        _pin.clear();
      });
      return;
    }
    setState(() => _busy = false);
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return SecurityAuthLayout(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              labelText: 'رمز الأمان',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            inputFormatters: [_digitsOnly, LengthLimitingTextInputFormatter(6)],
            enabled: !_busy,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('فتح التطبيق'),
          ),
        ],
      ),
    );
  }
}
