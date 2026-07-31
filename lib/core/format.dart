import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final compactCurrencyFormat = NumberFormat.compactCurrency(locale: 'en_PH', symbol: '₱');
final monthFormat = DateFormat('MMMM yyyy');
final monthAbbrevFormat = DateFormat('MMM');
final percentFormat = NumberFormat.percentPattern('en_PH')
  ..maximumFractionDigits = 1
  ..minimumFractionDigits = 1;

/// Parses a balance field's raw text (possibly comma-grouped, e.g.
/// `1,234.56`) into a [double], or `null` if it isn't a valid amount. Shared
/// by the balance field itself and the fat-finger anomaly guard so both
/// agree on what counts as a parseable number.
double? parseAmount(String raw) => double.tryParse(raw.replaceAll(',', ''));

/// Formats a signed month-over-month delta with its optional % change, e.g.
/// `+₱9,050.00 (+5.7%)` / `-₱550.00 (-0.4%)`. Shared by the Month List rows
/// and the Month Detail summary bar so both stay in lockstep.
String formatSignedDelta(double delta, double? pct) {
  final sign = delta >= 0 ? '+' : '';
  final amount = '$sign${currencyFormat.format(delta)}';
  if (pct == null) return amount;
  final pctSign = pct >= 0 ? '+' : '';
  return '$amount  ($pctSign${percentFormat.format(pct)})';
}
