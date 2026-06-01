import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'db/database_helper.dart';
import 'license_service.dart';
import 'theme/app_theme.dart';
import 'ui/app_security_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseHelper.initPlatform();
  final machineId = await LicenseService.getUniqueDeviceId();
  // ignore: avoid_print
  print('Machine ID: $machineId');
  await initializeDateFormatting('ar', null);
  // Touch the database eagerly so first navigation is instant.
  await DatabaseHelper.instance.database;
  runApp(const LegalErpApp());
}

class LegalErpApp extends StatelessWidget {
  const LegalErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light();
    return MaterialApp(
      title: 'نظام المكتب القانوني',
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(theme.textTheme),
      ),
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [Locale('ar', 'AE')],
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AppSecurityGate(),
    );
  }
}
