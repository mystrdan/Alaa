import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small local preference store. It keeps user choices on-device without an account.
/// Catalogue records should move to a transactional database before production.
class LocalPreferences {
  static const _countryKey = 'preferred_country';
  static const _favouritesKey = 'favourite_entry_ids';
  static const _contributionsKey = 'pending_contributions_v1';

  Future<String?> readCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_countryKey);
    return value == 'GH' || value == 'NG' ? value : null;
  }

  Future<void> saveCountry(String countryCode) async {
    if (countryCode != 'GH' && countryCode != 'NG') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, countryCode);
  }

  Future<Set<String>> readFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favouritesKey) ?? const <String>[]).toSet();
  }

  Future<void> saveFavourites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favouritesKey, ids.toList()..sort());
  }

  Future<List<Map<String, dynamic>>> readPendingContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contributionsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } on FormatException {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> savePendingContributions(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contributionsKey, jsonEncode(items));
  }
}
