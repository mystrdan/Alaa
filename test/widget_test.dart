import 'dart:io';
import 'dart:typed_data';

import 'package:alaa/data/catalogue_repository.dart';
import 'package:alaa/main.dart';
import 'package:alaa/models/ussd_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves catalogue assets from the real files on disk so widget tests exercise
/// the actual shipped catalogue instead of a hand-written copy.
class _DiskAssetBundle extends AssetBundle {
  _DiskAssetBundle();

  String _pathFor(String key) {
    final normalized = key.replaceAll('\\', '/');
    const prefix = 'catalogue/';
    final relative =
        normalized.startsWith(prefix) ? normalized.substring(prefix.length) : normalized;
    return 'catalogue/$relative';
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(_pathFor(key)).readAsStringSync();

  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(_pathFor(key)).readAsBytes();
    final builder = BytesBuilder(copy: false)..add(bytes);
    return ByteData.view(builder.toBytes().buffer);
  }
}

CatalogueRepository _realCatalogueRepository() =>
    CatalogueRepository(bundle: _DiskAssetBundle());

/// Renders on a tall virtual screen so the lazy [ListView]s build their full
/// contents. Widget-test `find` assertions can only see built widgets, and the
/// first-run welcome card plus headers push service tiles below the default
/// 800x600 viewport, so those children would never be constructed.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Back local persistence with the in-memory mock store; without this the
    // real preferences platform channel never answers in tests and awaited
    // saves never complete.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpApp(WidgetTester tester, {CatalogueRepository? repository}) async {
    _useTallViewport(tester);
    await tester.pumpWidget(AlaaApp(
      catalogueRepository: repository ?? _realCatalogueRepository(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Alaa opens on the offline-first home screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('What do you need to do?'), findsOneWidget);
    expect(find.text('Works offline'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
  });

  testWidgets('first run asks the user to confirm their country', (tester) async {
    await pumpApp(tester);
    expect(find.text('Welcome! Which country are you in?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nigeria'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome! Which country are you in?'), findsNothing);
    expect(find.text('Check data balance'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('preferred_country'), 'NG');
  });

  testWidgets('search matches user intent and codes', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'buy data');
    await tester.pumpAndSettle();
    expect(find.text('Buy data bundles'), findsOneWidget);
    expect(find.text('Check my MTN number'), findsNothing);

    await tester.enterText(find.byType(TextField), '*156#');
    await tester.pumpAndSettle();
    expect(find.text('Check my MTN number'), findsOneWidget);
    expect(find.text('Buy data bundles'), findsNothing);
  });

  testWidgets('category browsing filters to matching services', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data & airtime'));
    await tester.pumpAndSettle();
    expect(find.text('Buy data bundles'), findsOneWidget);
    expect(find.text('Check my MTN number'), findsNothing);
  });

  testWidgets('empty search shows an empty state', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'zzz no such service');
    await tester.pumpAndSettle();
    expect(find.text('No matching services'), findsOneWidget);
  });

  testWidgets('favourites save services locally', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add favourite').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();
    expect(find.text('Buy data bundles'), findsOneWidget);
  });

  testWidgets('verified entries enable the dialer action', (tester) async {
    final entry = UssdEntry(
      id: 'gh-mtn-check-my-number',
      name: 'Check my MTN number',
      description: 'Show your own MTN Ghana phone number on your screen.',
      countryCode: 'GH',
      provider: 'MTN',
      category: 'Account & balance',
      dialString: '*156#',
      instructions: <String>['Dial *156#.'],
      status: VerificationStatus.verified,
      sourceUrl: 'https://example.com/source',
      verifiedAt: DateTime(2026, 10, 11),
    );
    _useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(home: ServiceDetailPage(entry: entry, onFavourite: () {})));
    await tester.pumpAndSettle();

    final dialButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Open USSD dialer'), matching: find.byType(FilledButton)).first,
    );
    expect(dialButton.onPressed, isNotNull);
    expect(find.text('Last checked: 2026-10-11'), findsOneWidget);
    expect(find.textContaining('https://example.com/source'), findsOneWidget);
  });

  testWidgets('unverified entries never enable dial', (tester) async {
    const entry = UssdEntry(
      id: 'ng-draft-sample',
      name: 'Sample draft',
      description: 'A draft entry with an unconfirmed code.',
      countryCode: 'NG',
      provider: 'Example',
      category: 'Account & balance',
      dialString: '*999#',
      instructions: <String>['Dial *999#.'],
      status: VerificationStatus.unverified,
    );
    _useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(home: ServiceDetailPage(entry: entry, onFavourite: () {})));
    await tester.pumpAndSettle();

    expect(find.text('USSD code not verified'), findsOneWidget);
    final dialButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('USSD code not verified'), matching: find.byType(FilledButton)).first,
    );
    expect(dialButton.onPressed, isNull);
    // The status badge appears both as the header Chip and in the
    // Verification detail card, so it is expected more than once.
    expect(find.text('Unverified — not confirmed by a source yet'), findsWidgets);
    expect(find.text('Copy code'), findsOneWidget);
    expect(find.textContaining('cannot see what happens in the carrier session'), findsOneWidget);
  });
}
