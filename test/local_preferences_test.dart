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

    await store.saveFavourites(<String>{'bundle-data', 'balance', 'bundle-data'});

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
}
