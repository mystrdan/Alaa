enum VerificationStatus { verified, unverified, stale, disputed, retired }

/// How the user actually reaches the service behind an entry.
enum ServiceType {
  ussd('ussd'),
  smsShortCode('sms_short_code'),
  phoneNumber('phone_number'),
  webLink('web_link');

  const ServiceType(this.jsonValue);
  final String jsonValue;

  static ServiceType? tryParse(String? raw) {
    for (final value in ServiceType.values) {
      if (value.jsonValue == raw) return value;
    }
    return null;
  }
}

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
    this.serviceType = ServiceType.ussd,
    this.networkScope,
    this.costNote,
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
  final ServiceType serviceType;

  /// Plan, region, or SIM scope notes, e.g. "Prepaid MTN SIMs".
  final String? networkScope;

  /// Cost caveats, e.g. "Standard USSD charges may apply".
  final String? costNote;

  final String? sourceUrl;
  final DateTime? verifiedAt;
  final VerificationStatus status;

  String get countryName => switch (countryCode) {
        'GH' => 'Ghana',
        'NG' => 'Nigeria',
        _ => countryCode,
      };

  /// The verification gate: only individually verified entries with a real
  /// dial string may be handed to the device dialer.
  bool get canLaunchDialer =>
      status == VerificationStatus.verified && dialString.trim().isNotEmpty;

  VerificationStatus get effectiveStatus {
    if (status == VerificationStatus.verified &&
        verifiedAt != null &&
        DateTime.now().toUtc().difference(verifiedAt!.toUtc()).inDays > 180) {
      return VerificationStatus.stale;
    }
    return status;
  }

  static const _intentCategories = <String, List<String>>{
    'data & airtime': ['buy data', 'data', 'internet', 'bundle', 'bundles', 'airtime', 'recharge', 'top up', 'topup'],
    'account & balance': ['check balance', 'balance', 'check number', 'my number', 'number', 'borrow', 'loan'],
    'mobile money': ['mobile money', 'momo', 'send money', 'wallet', 'payment', 'pay'],
    'banking': ['bank', 'banking', 'account number'],
    'sim & network': ['sim', 'network', 'tariff', 'plan'],
    'customer care': ['support', 'complaint', 'help', 'care'],
  };

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = <String>[
      name,
      description,
      countryCode,
      countryName,
      provider,
      category,
      dialString,
      ...instructions,
      if (networkScope != null) networkScope!,
      if (costNote != null) costNote!,
    ].join(' • ').toLowerCase();
    if (haystack.contains(q)) return true;
    // Intent matching: treat the query as a goal (e.g. "check balance",
    // "buy data") and also match entries whose category the goal maps to.
    final intentTerms = _intentCategories[category.toLowerCase()];
    if (intentTerms == null) return false;
    final words = q.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();
    return intentTerms.any((term) => term.contains(' ')
        ? q.contains(term)
        : words.contains(term));
  }
}
