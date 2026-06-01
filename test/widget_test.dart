import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lawer_system/license_service.dart';
import 'package:lawer_system/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LegalErpApp builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      LicenseService.prefsKeyIsActivated: true,
    });
    await tester.pumpWidget(const LegalErpApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}