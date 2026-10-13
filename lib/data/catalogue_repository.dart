import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ussd_entry.dart';

/// Outcome of parsing one country catalogue file.
class CatalogueParseResult {
  const CatalogueParseResult({required this.entries, required this.warnings});

  final List<UssdEntry> entries;
  final List<String> warnings;
}

class CatalogueLoadException implements Exception {
  const CatalogueLoadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parses the bundled per-country catalogue JSON into [UssdEntry] records.
///
/// Parsing is tolerant per entry: a malformed entry is skipped and reported
/// in [CatalogueParseResult.warnings] so one bad record cannot blank the
/// whole catalogue, while the build-time validator rejects such files from
/// ever being released.
CatalogueParseResult parseCountryEntries(
  String jsonString,
  String expectedCountry, {
  DateTime? nowUtc,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonString);
  } on FormatException catch (exc) {
    throw CatalogueLoadException('Catalogue is not valid JSON: $exc');
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['entries'] is! List ||
      decoded['countryCode'] != expectedCountry) {
    throw const CatalogueLoadException(
        'Catalogue file must contain matching countryCode and an entries array');
  }
  final now = nowUtc ?? DateTime.now().toUtc();
  final entries = <UssdEntry>[];
  final warnings = <String>[];
  for (final raw in decoded['entries'] as List<dynamic>) {
    try {
      entries.add(_parseEntry(raw, expectedCountry, now));
    } on Object catch (exc) {
      warnings.add('Skipped malformed entry: $exc');
    }
  }
  return CatalogueParseResult(entries: entries, warnings: warnings);
}

UssdEntry _parseEntry(Object? raw, String expectedCountry, DateTime now) {
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('entry is not an object');
  }
  String requiredString(String key) {
    final value = raw[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string');
    }
    return value.trim();
  }

  final countryCode = requiredString('countryCode');
  if (countryCode != expectedCountry) {
    throw FormatException('countryCode $countryCode does not match $expectedCountry');
  }
  final serviceType = ServiceType.tryParse(raw['serviceType'] ?? 'ussd');
  if (serviceType == null) {
    throw const FormatException('unsupported serviceType');
  }
  final status = switch (raw['verificationStatus']) {
    'verified' => VerificationStatus.verified,
    'corroborated' => VerificationStatus.corroborated,
    'stale' => VerificationStatus.stale,
    'disputed' => VerificationStatus.disputed,
    'retired' => VerificationStatus.retired,
    'historical' => VerificationStatus.historical,
    // 'draft' and any unknown value map to unverified: a lead, clearly
    // labelled, never presented as confirmed.
    _ => VerificationStatus.unverified,
  };
  final serviceStatus =
      ServiceStatus.tryParse(raw['serviceStatus'] as String?) ??
          ServiceStatus.unknown;
  final instructions = <String>[];
  final rawInstructions = raw['instructions'];
  if (rawInstructions is List) {
    for (final step in rawInstructions) {
      if (step is String) instructions.add(step);
    }
  }
  final verifiedAt = _parseDate(raw['verifiedAt']);
  if (status == VerificationStatus.verified) {
    if (raw['sourceUrl'] is! String ||
        !(raw['sourceUrl'] as String).startsWith('https://')) {
      throw const FormatException('verified entries require an HTTPS sourceUrl');
    }
    if (verifiedAt == null) {
      throw const FormatException('verified entries require verifiedAt');
    }
    if (now.difference(verifiedAt.toUtc()).inDays < -1) {
      throw const FormatException('verifiedAt must not be in the future');
    }
  }
  final dialString = raw['dialString'];
  if (dialString is! String) {
    throw const FormatException('dialString must be a string');
  }
  String? optionalString(String key) {
    final value = raw[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  final tags = <String>[];
  final rawTags = raw['tags'];
  if (rawTags is List) {
    for (final tag in rawTags) {
      if (tag is String && tag.trim().isNotEmpty) tags.add(tag.trim());
    }
  }

  return UssdEntry(
    id: requiredString('id'),
    name: requiredString('name'),
    description: requiredString('description'),
    countryCode: countryCode,
    provider: requiredString('provider'),
    category: requiredString('category'),
    subcategory: optionalString('subcategory'),
    serviceType: serviceType,
    serviceStatus: serviceStatus,
    dialString: dialString.trim(),
    instructions: instructions,
    networkScope: optionalString('networkScope'),
    eligibility: optionalString('eligibility'),
    costNote: optionalString('costNote'),
    securityWarning: optionalString('securityWarning'),
    tags: tags,
    sourceUrl: raw['sourceUrl'] is String ? raw['sourceUrl'] as String : null,
    sourceTitle: optionalString('sourceTitle'),
    sourcePublisher: optionalString('sourcePublisher'),
    verifiedAt: verifiedAt,
    lastCheckedAt: _parseDate(raw['lastCheckedAt']),
    status: status,
  );
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// Loads the bundled offline catalogue. The bundled copy is always available
/// without a network connection.
class CatalogueRepository {
  CatalogueRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const supportedCountries = <String>['GH', 'NG'];

  Future<CatalogueParseResult> loadCountry(String countryCode) async {
    if (!supportedCountries.contains(countryCode)) {
      throw const CatalogueLoadException('Unsupported country');
    }
    final String raw;
    try {
      raw = await _bundle.loadString('catalogue/countries/$countryCode/services.json');
    } on Object catch (exc) {
      throw CatalogueLoadException('Could not load bundled catalogue for $countryCode: $exc');
    }
    return parseCountryEntries(raw, countryCode);
  }

  /// Loads every supported country, collecting parse warnings. A single
  /// unreadable country must not hide the others, so failures are surfaced in
  /// [CatalogueLoadOutcome.errors] while the rest of the catalogue still loads.
  Future<CatalogueLoadOutcome> loadAll() async {
    final byCountry = <String, List<UssdEntry>>{};
    final warnings = <String>[];
    final errors = <String>[];
    for (final country in supportedCountries) {
      try {
        final result = await loadCountry(country);
        byCountry[country] = result.entries;
        warnings.addAll(result.warnings);
      } on CatalogueLoadException catch (exc) {
        errors.add(exc.message);
      }
    }
    return CatalogueLoadOutcome(
      byCountry: byCountry,
      warnings: warnings,
      errors: errors,
    );
  }
}

/// Result of loading the whole bundled catalogue across every country.
class CatalogueLoadOutcome {
  const CatalogueLoadOutcome({
    required this.byCountry,
    required this.warnings,
    required this.errors,
  });

  final Map<String, List<UssdEntry>> byCountry;
  final List<String> warnings;
  final List<String> errors;
}