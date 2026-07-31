import 'monthly_entry.dart';

String _monthId(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Consecutive months with a logged entry, counting backward from [asOf]
/// (defaults to now). If the current month hasn't been logged yet, it isn't
/// counted but also doesn't break the streak — an in-progress month is
/// simply skipped, so the streak reflects consecutive *completed* months.
/// Purely derived, no persistence of its own.
int computeLoggedStreak(List<MonthlyEntry> entries, {DateTime? asOf}) {
  final now = asOf ?? DateTime.now();
  final loggedIds = entries.map((e) => e.id).toSet();

  var cursor = DateTime(now.year, now.month);
  if (!loggedIds.contains(_monthId(cursor))) {
    cursor = DateTime(cursor.year, cursor.month - 1);
  }

  var streak = 0;
  while (loggedIds.contains(_monthId(cursor))) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month - 1);
  }
  return streak;
}
