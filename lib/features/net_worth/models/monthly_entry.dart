/// One month's snapshot: a balance per account id (sparse — an account with
/// no entry that month is simply absent, matching blank cells in the
/// original spreadsheet) plus an optional free-text note.
class MonthlyEntry {
  MonthlyEntry({
    required this.month,
    required this.balances,
    this.note,
    this.locked = false,
  });

  /// First day of the month, e.g. 2025-04-01. Doc id is derived from this.
  final DateTime month;
  final Map<String, double> balances;
  final String? note;

  /// When true, this month is finalized and its fields should be read-only
  /// in the editor — toggled immediately (its own save call), not folded
  /// into the next explicit Save.
  final bool locked;

  String get id =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  factory MonthlyEntry.fromMap(String id, Map<String, dynamic> map) {
    final parts = id.split('-');
    final rawBalances = (map['balances'] as Map?) ?? const {};
    return MonthlyEntry(
      month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
      balances: rawBalances.map(
        (key, value) => MapEntry(key as String, (value as num).toDouble()),
      ),
      note: map['note'] as String?,
      locked: map['locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'balances': balances,
      'note': note,
      'locked': locked,
    };
  }

  MonthlyEntry copyWith({
    Map<String, double>? balances,
    String? note,
    bool? locked,
  }) {
    return MonthlyEntry(
      month: month,
      balances: balances ?? this.balances,
      note: note ?? this.note,
      locked: locked ?? this.locked,
    );
  }
}
