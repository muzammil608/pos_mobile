import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/main.dart';

void main() {
  testWidgets('POS app starts without the old counter template',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
  });
}





