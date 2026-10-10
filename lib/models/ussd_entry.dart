enum VerificationStatus { verified, unverified, stale, disputed, retired }

class UssdEntry {
  const UssdEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.countryCode,
    required this.provider,
    required this.category,
    required this.dialString,
    required this.instructions,
    this.sourceUrl,
    this.verifiedAt,
    this.status = VerificationStatus.unverified,
  });

  final String id;
  final String name;
  final String description;
  final String countryCode;
  final String provider;
  final String category;
  final String dialString;
  final List<String> instructions;
  final String? sourceUrl;
  final DateTime? verifiedAt;
  final VerificationStatus status;

  String get countryName => switch (countryCode) {
        'GH' => 'Ghana',
        'NG' => 'Nigeria',
        _ => countryCode,
      };

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return <String>[name, description, countryCode, countryName, provider, category, dialString]
        .any((value) => value.toLowerCase().contains(q));
  }
}
