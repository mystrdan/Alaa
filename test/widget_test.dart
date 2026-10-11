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
  testWidgets('report and suggestion actions open distinct contribution forms', (tester) async {
    await tester.pumpWidget(const AlaaApp());
    await tester.tap(find.text('Contribute').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report a broken code'));
    await tester.pumpAndSettle();
    expect(find.text('Report a broken code'), findsNWidgets(2));
    expect(find.text('Suggest a code'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suggest a USSD code'));
    await tester.pumpAndSettle();
    expect(find.text('Suggest a code'), findsOneWidget);
    expect(find.text('Report a broken code'), findsOneWidget);
  });

}
