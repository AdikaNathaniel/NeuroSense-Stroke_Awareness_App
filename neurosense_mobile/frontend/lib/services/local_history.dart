import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// On-device assessment history. Mirrors the shape the backend's
/// /api/v1/history/me used to return so the analytics screen renders unchanged.
/// Storage is keyed per-user (by email) so multiple accounts on the same
/// device don't see each other's records.
class LocalHistory {
  static const _prefix = 'assessment_history:';

  /// Bumps every time [add] or [clear] mutates storage. Listeners (e.g. the
  /// analytics screen) can rebuild themselves when this changes.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<String> _key() async {
    final email = await ApiService.getUserEmail() ?? 'anonymous';
    return '$_prefix$email';
  }

  /// Returns records in chronological order (oldest first), matching the
  /// backend's `sort({createdAt: 1})`.
  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _key());
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(Map<String, dynamic> record) async {
    final all = (await getAll()).toList();
    all.add({...record, 'createdAt': DateTime.now().toIso8601String()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _key(), jsonEncode(all));
    revision.value++;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _key());
    revision.value++;
  }
}
