import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_client_app/main.dart';

void main() {
  testWidgets('Client home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientApp());

    expect(find.text('Where to?'), findsOneWidget);
  });
}
