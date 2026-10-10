import 'package:alaa/models/ussd_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const entry = UssdEntry(
    id: 'sample-gh-data',
    name: 'Data bundles',
    description: 'Buy a mobile data bundle',
    countryCode: 'GH',
    provider: 'Example Network',
    category: 'Data & airtime',
    dialString: '',
    instructions: <String>['Choose a bundle'],
    status: VerificationStatus.unverified,
  );

  test('country code resolves to a display name', () {
    expect(entry.countryName, 'Ghana');
  });

  test('search matches intent, provider, country, and code', () {
    expect(entry.matches('buy a mobile'), isTrue);
    expect(entry.matches('example network'), isTrue);
    expect(entry.matches('ghana'), isTrue);
    expect(entry.matches('missing service'), isFalse);
    expect(entry.matches('  '), isTrue);
  });

  test('demo entry is not verified by default', () {
    expect(entry.status, VerificationStatus.unverified);
  });
}
