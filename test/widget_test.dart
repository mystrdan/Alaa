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
    Navigator.of(tester.element(find.text('Report a broken code').last)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suggest a USSD code'));
    await tester.pumpAndSettle();
    expect(find.text('Suggest a code'), findsOneWidget);
    expect(find.text('Report a broken code'), findsOneWidget);
  });

  testWidgets('local contribution drafts can be deleted from the queue', (tester) async {
    await tester.pumpWidget(const AlaaApp());
    await tester.tap(find.text('Contribute').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest a USSD code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Service name'), 'Test service');
    await tester.enterText(find.widgetWithText(TextField, 'What does it do?'), 'Test description');
    await tester.tap(find.text('Save on this device'));
    await tester.pumpAndSettle();

    expect(find.text('Test service'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete local draft'));
    await tester.pumpAndSettle();

    expect(find.text('Test service'), findsNothing);
    expect(find.text('No contributions yet'), findsOneWidget);
    expect(find.text('Local draft deleted.'), findsOneWidget);
  });

}
