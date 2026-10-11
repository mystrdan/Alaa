import 'package:alaa/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Alaa opens on the offline-first home screen', (tester) async {
    await tester.pumpWidget(const AlaaApp());
    expect(find.text('What do you need to do?'), findsOneWidget);
    expect(find.text('Works offline'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
  });

  testWidgets('unverified demo services cannot launch a USSD session', (tester) async {
    await tester.pumpWidget(const AlaaApp());
    await tester.tap(find.text('Data bundles').first);
    await tester.pumpAndSettle();

    expect(find.text('USSD code not verified'), findsOneWidget);
    final dialButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('USSD code not verified'),
        matching: find.byType(FilledButton),
      ).first,
    );
    expect(dialButton.onPressed, isNull);
    expect(find.textContaining('Development preview'), findsOneWidget);
  });
}
