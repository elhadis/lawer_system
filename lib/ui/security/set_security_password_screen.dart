import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'security_auth_layout.dart';

/// First-time setup: six-digit PIN (Layer 2).
class SetSecurityPasswordScreen extends StatefulWidget {
  const SetSecurityPasswordScreen({
    super.key,
    required this.onPinSaved,
  });

  final Future<void> Function(String pin6) onPinSaved;

  @override
  State<SetSecurityPasswordScreen> createState() =>
      _SetSecurityPasswordScreenState();
}

class _SetSecurityPasswordScreenState extends State<SetSecurityPasswordScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;
  String? _error;

  static final _digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (a.length != 6) {
      setState(() => _error = 'يجب إدخال 6 أرقام بالضبط.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'الرقمان غير متطابقين.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPinSaved(a);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecurityAuthLayout(
      title: 'Set Your Security Password',
      subtitle:
          'اختر رمزاً مكوّناً من 6 أرقام. سيُطلب منك عند فتح التطبيق وعند القفل اليدوي.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pin1,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              labelText: 'الرمز (6 أرقام)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            inputFormatters: [_digitsOnly, LengthLimitingTextInputFormatter(6)],
            enabled: !_busy,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pin2,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              labelText: 'تأكيد الرمز',
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
                : const Text('حفظ ومتابعة'),
          ),
        ],
      ),
    );
  }
}
