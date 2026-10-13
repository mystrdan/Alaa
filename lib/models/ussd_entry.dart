/// Verification status of a catalogue entry.
///
/// These map to the research policy:
/// - [verified]: exact code + purpose from a strong primary source, dated.
/// - [corroborated]: credible sources agree but no direct primary confirmation.
/// - [unverified]: a lead (secondary/community) — allowed to dial but clearly
///   labelled as unconfirmed; never presented as working truth.
/// - [historical]: dated evidence; possibly discontinued. Dial disabled.
/// - [stale]: derived — a [verified] entry whose check date is old.
/// - [disputed]: sources conflict or it was reported wrong. Dial disabled.
/// - [retired]: withdrawn by the operator. Dial disabled.
enum VerificationStatus { verified, corroborated, unverified, historical, stale, disputed, retired }

/// Lifecycle of the underlying service, independent of our verification.
enum ServiceStatus {
  active('active'),
  temporary('temporary'),
  seasonal('seasonal'),
  historical('historical'),
  discontinued('discontinued'),
  unknown('unknown');

  const ServiceStatus(this.jsonValue);
  final String jsonValue;

  static ServiceStatus? tryParse(String? raw) {
    for (final value in ServiceStatus.values) {
      if (value.jsonValue == raw) return value;
    }
    return null;
  }
}

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
    this.subcategory,
    this.serviceType = ServiceType.ussd,
    this.serviceStatus = ServiceStatus.unknown,
    this.networkScope,
    this.eligibility,
    this.costNote,
    this.securityWarning,
    this.tags = const <String>[],
    this.sourceUrl,
    this.sourceTitle,
    this.sourcePublisher,
    this.verifiedAt,
    this.lastCheckedAt,
    this.status = VerificationStatus.unverified,
  });

  final String id;
  final String name;
  final String description;
  final String countryCode;
  final String provider;

  /// One of the data-driven sector categories in [categories].
  final String category;

  /// Optional finer grouping within a category, e.g. "Prepaid recharge".
  final String? subcategory;

  final String dialString;
  final List<String> instructions;
  final ServiceType serviceType;

  /// Lifecycle of the underlying service (active, temporary, retired, ...).
  final ServiceStatus serviceStatus;

  /// Plan, region, or SIM scope notes, e.g. "Prepaid MTN SIMs".
  final String? networkScope;

  /// Who/what the service applies to, e.g. "Postpaid customers only".
  final String? eligibility;

  /// Cost caveats, e.g. "Standard USSD charges may apply".
  final String? costNote;

  /// Privacy/transaction warning, e.g. "May expose personal data".
  final String? securityWarning;

  /// Extra search terms / aliases (e.g. "check balance", "buy data").
  final List<String> tags;

  final String? sourceUrl;

  /// Human-readable source metadata for the detail page and re-checking.
  final String? sourceTitle;
  final String? sourcePublisher;

  /// When the code was last confirmed against [sourceUrl] (verified entries).
  final DateTime? verifiedAt;

  /// When this record was last reviewed, even if not fully verified.
  final DateTime? lastCheckedAt;

  final VerificationStatus status;

  /// The 11-sector taxonomy. Data-driven so new sectors need no code redesign.
  static const categories = <String>[
    'Telecom',
    'Government',
    'Education',
    'Finance and Payments',
    'Health',
    'Utilities',
    'Transport',
    'Agriculture',
    'Insurance and Pensions',
    'Commerce',
    'Other Services',
  ];

  String get countryName => switch (countryCode) {
        'GH' => 'Ghana',
        'NG' => 'Nigeria',
        _ => countryCode,
      };

  /// The dialer gate. Per product decision, users may dial verified,
  /// corroborated, and unverified entries (with clear labels), but never
  /// retired, disputed, or historical codes, and only with a real dial string.
  bool get canLaunchDialer {
    final effective = effectiveStatus;
    return switch (effective) {
      VerificationStatus.retired ||
      VerificationStatus.disputed ||
      VerificationStatus.historical =>
        false,
      _ => dialString.trim().isNotEmpty,
    };
  }

  VerificationStatus get effectiveStatus {
    if (status == VerificationStatus.verified &&
        verifiedAt != null &&
        DateTime.now().toUtc().difference(verifiedAt!.toUtc()).inDays > 180) {
      return VerificationStatus.stale;
    }
    return status;
  }

  static const _intentCategories = <String, List<String>>{
    'telecom': ['buy data', 'data', 'internet', 'bundle', 'bundles', 'airtime', 'recharge', 'top up', 'topup', 'balance', 'check balance', 'my number', 'check number', 'borrow', 'loan', 'tariff', 'plan', 'sim', 'network'],
    'government': ['tax', 'tin', 'passport', 'national id', 'ssnit', 'nhis', 'registration', 'permit', 'government'],
    'education': ['admission', 'result', 'results', 'waec', 'school', 'exam', 'student', 'portal', 'check result', 'application status'],
    'finance and payments': ['bank', 'transfer', 'send money', 'mobile money', 'momo', 'pay', 'payment', 'bill', 'account number', 'wallet'],
    'health': ['hospital', 'clinic', 'health', 'nhis', 'insurance', 'doctor', 'pharmacy', 'book appointment'],
    'utilities': ['electricity', 'meter', 'prepaid', 'postpaid', 'water', 'bill', 'ecg', 'dumsor', 'token', 'recharge meter'],
    'transport': ['ticket', 'bus', 'flight', 'driver', 'vehicle', 'license', 'licence', 'toll'],
    'agriculture': ['market price', 'weather', 'farm', 'crop', 'input', 'extension', 'subsidy'],
    'insurance and pensions': ['insurance', 'pension', 'policy', 'premium'],
    'commerce': ['shop', 'store', 'order', 'retail', 'buy'],
    'other services': ['service', 'other'],
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
      if (subcategory != null) subcategory!,
      dialString,
      ...instructions,
      ...tags,
      if (networkScope != null) networkScope!,
      if (eligibility != null) eligibility!,
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
