import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendora/features/shared/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard widget renders child content properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            child: Text('Attendora Glass Component'),
          ),
        ),
      ),
    );

    expect(find.text('Attendora Glass Component'), findsOneWidget);
    expect(find.byType(GlassCard), findsOneWidget);
  });
}
