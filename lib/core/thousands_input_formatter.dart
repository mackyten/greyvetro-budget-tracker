import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _digit = RegExp(r'\d');
final _groupFormat = NumberFormat('#,##0');

/// Keeps digits and at most one decimal point, capped at [decimalDigits]
/// fractional digits — the same constraint the old
/// `FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))` enforced.
String _clean(String text, int decimalDigits) {
  final buffer = StringBuffer();
  var seenDecimalPoint = false;
  var decimalDigitsSeen = 0;
  for (final char in text.split('')) {
    if (_digit.hasMatch(char)) {
      if (seenDecimalPoint) {
        if (decimalDigitsSeen >= decimalDigits) continue;
        decimalDigitsSeen++;
      }
      buffer.write(char);
    } else if (char == '.' && !seenDecimalPoint) {
      seenDecimalPoint = true;
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Groups a plain numeric string's integer portion with thousands
/// separators (e.g. `1234567.89` -> `1,234,567.89`). Used both by the live
/// [ThousandsInputFormatter] and for one-off values (initial field text, the
/// cash-counter callback) that need the identical grouping outside of an
/// active edit.
String formatGrouped(String text, {int decimalDigits = 2}) {
  final cleaned = _clean(text, decimalDigits);
  final dotIndex = cleaned.indexOf('.');
  final integerPart = dotIndex == -1 ? cleaned : cleaned.substring(0, dotIndex);
  final fractionPart = dotIndex == -1 ? '' : cleaned.substring(dotIndex);
  final groupedInteger =
      integerPart.isEmpty ? '' : _groupFormat.format(int.parse(integerPart));
  return '$groupedInteger$fractionPart';
}

/// Live-groups the integer portion of a balance field with thousands
/// separators while typing, replacing the plain digit-filtering formatter
/// these fields used before. Cursor position is remapped by digit count
/// rather than raw character offset, since inserting/removing grouping
/// separators shifts every character after them.
class ThousandsInputFormatter extends TextInputFormatter {
  ThousandsInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawText = newValue.text;
    final cursorOffset = newValue.selection.end.clamp(0, rawText.length);
    final digitsBeforeCursor = _digitCount(rawText.substring(0, cursorOffset));

    final formatted = formatGrouped(rawText, decimalDigits: decimalDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetForDigitCount(formatted, digitsBeforeCursor),
      ),
    );
  }

  int _digitCount(String s) => s.split('').where(_digit.hasMatch).length;

  int _offsetForDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_digit.hasMatch(formatted[i])) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return formatted.length;
  }
}
