import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taxi_client_app/app.dart';
import 'package:taxi_client_app/pages/login_page.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const TaxiSuperApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
  });
}
