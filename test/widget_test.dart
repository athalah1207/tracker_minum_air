// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:tracker_minum_air/main.dart' as app;


void main() {
  testWidgets('Aplikasi dapat dimuat dengan baik', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Memastikan elemen utama HydroTracker muncul di layar
    expect(find.text('HydroTracker'), findsOneWidget);
  });
}
