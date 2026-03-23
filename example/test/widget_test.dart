import 'package:flutter_test/flutter_test.dart';
import 'package:topology_view_example/main.dart';

void main() {
  testWidgets('Playground renders with sidebar and presets',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TopologyViewExampleApp());
    await tester.pumpAndSettle();

    // Sidebar preset buttons
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);

    // Section headers
    expect(find.text('PRESETS'), findsOneWidget);
    expect(find.text('WIDGET CONFIG'), findsOneWidget);
    expect(find.text('DATA INFO'), findsOneWidget);
    expect(find.text('DATA TWEAKS'), findsOneWidget);
  });
}
