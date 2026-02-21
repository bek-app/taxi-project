import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_client_app/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TaxiSuperApp());

    expect(find.text('Email'), findsOneWidget);
  });
}
