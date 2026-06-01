import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../license_service.dart';
import 'app_shell.dart';

/// Standalone activation gate (Layer 1). When [onActivated] is set, it is
/// called instead of navigating to [AppShell] (used by [AppSecurityGate]).
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key, this.onActivated});

  final VoidCallback? onActivated;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _keyController = TextEditingController();

  String? _deviceId;
  String? _loadError;
  bool _loadingId = true;
  bool _submitting = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    setState(() {
      _loadingId = true;
      _loadError = null;
    });
    try {
      final id = await LicenseService.getUniqueDeviceId();
      if (!mounted) return;
      setState(() {
        _deviceId = id;
        _loadingId = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingId = false;
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _onActivate() async {
    final id = _deviceId;
    if (id == null || id.isEmpty) {
      setState(() => _feedback = 'تعذر قراءة معرف الجهاز.');
      return;
    }
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    final ok = LicenseService.verifyActivationKey(
      machineId: id,
      enteredKey: _keyController.text,
    );
    if (!ok) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _feedback = 'مفتاح التفعيل غير صحيح.';
        });
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LicenseService.prefsKeyIsActivated, true);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (widget.onActivated != null) {
      widget.onActivated!();
    } else {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AppShell(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفعيل النظام'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'معرف الجهاز',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _loadingId
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : SelectableText(
                              _loadError ?? _deviceId ?? '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'مفتاح التفعيل',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enabled: !_submitting && !_loadingId,
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _feedback!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting || _loadingId ? null : _onActivate,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تفعيل الآن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
