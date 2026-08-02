import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App launches and shows PathIQ AI home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Let the router settle
    await tester.pumpAndSettle();

    expect(find.text('PathIQ AI — Milestone M1 Base'), findsOneWidget);
  });
}