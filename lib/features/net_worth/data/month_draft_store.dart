import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// In-progress, unsaved edits for one month's entry — kept on-device only.
class MonthDraft {
  const MonthDraft({required this.balances, required this.note});

  /// Raw text as typed (not parsed), keyed by account id.
  final Map<String, String> balances;
  final String note;

  factory MonthDraft.fromJson(Map<String, dynamic> json) {
    final rawBalances = (json['balances'] as Map?) ?? const {};
    return MonthDraft(
      balances: rawBalances.map((key, value) => MapEntry(key as String, value as String)),
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'balances': balances, 'note': note};
}

/// Persists Month Detail edits locally the moment they're typed, so an
/// accidental back-gesture/dismiss doesn't lose in-progress data entry — the
/// draft survives until [clear] is called after an explicit Save.
class MonthDraftStore {
  MonthDraftStore._();
  static final instance = MonthDraftStore._();

  static String _key(String monthEntryId) => 'month_draft_$monthEntryId';

  Future<MonthDraft?> load(String monthEntryId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(monthEntryId));
    if (raw == null) return null;
    return MonthDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(String monthEntryId, MonthDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(monthEntryId), jsonEncode(draft.toJson()));
  }

  Future<void> clear(String monthEntryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(monthEntryId));
  }
}
