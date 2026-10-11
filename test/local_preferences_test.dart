import 'package:alaa/data/local_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('country preference only accepts supported countries', () async {
    final store = LocalPreferences();

    expect(await store.readCountry(), isNull);
    await store.saveCountry('US');
    expect(await store.readCountry(), isNull);
    await store.saveCountry('GH');
    expect(await store.readCountry(), 'GH');
    await store.saveCountry('NG');
    expect(await store.readCountry(), 'NG');
  });

  test('favourites persist as unique IDs', () async {
    final store = LocalPreferences();

    await store.saveFavourites(<String>{'bundle-data', 'balance'});

    expect(await store.readFavourites(), <String>{'bundle-data', 'balance'});
  });

  test('pending contribution drafts persist locally', () async {
    final store = LocalPreferences();
    final draft = <String, dynamic>{
      'id': 'draft-1',
      'type': 'suggestion',
      'countryCode': 'GH',
      'description': 'Example only',
      'status': 'pending',
    };

    await store.savePendingContributions(<Map<String, dynamic>>[draft]);

    expect(await store.readPendingContributions(), <Map<String, dynamic>>[draft]);
  });

  test('invalid pending contribution JSON safely returns an empty list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pending_contributions_v1': '{not-json',
    });

    expect(await LocalPreferences().readPendingContributions(), isEmpty);
  });

  test('unsupported stored country falls back to automatic selection', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'preferred_country': 'US',
    });

    expect(await LocalPreferences().readCountry(), isNull);
  });

  test('non-list contribution payload safely returns an empty list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pending_contributions_v1': '{"unexpected":"object"}',
    });

    expect(await LocalPreferences().readPendingContributions(), isEmpty);
  });

  test('contribution payload ignores non-object list items', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pending_contributions_v1': '[{"id":"draft-1"},null,"invalid",3]',
    });

    expect(
      await LocalPreferences().readPendingContributions(),
      <Map<String, dynamic>>[<String, dynamic>{'id': 'draft-1'}],
    );
  });

  test('wrong stored preference types safely fall back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'preferred_country': 42,
      'favourite_entry_ids': 'not-a-list',
    });

    final store = LocalPreferences();
    expect(await store.readCountry(), isNull);
    expect(await store.readFavourites(), isEmpty);
  });

  test('malformed contribution items with invalid map types are ignored safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pending_contributions_v1': '[{"valid":"draft"}, {"nested":[1,2]}]',
    });

    expect(
      await LocalPreferences().readPendingContributions(),
      <Map<String, dynamic>>[
        <String, dynamic>{'valid': 'draft'},
        <String, dynamic>{'nested': <dynamic>[1, 2]},
      ],
    );
  });
}
