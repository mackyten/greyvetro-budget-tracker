import '../../../core/format.dart';

const _ones = {
  'zero': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const _tens = {
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

/// Parses a spoken balance amount, e.g. "twelve thousand five hundred
/// pesos" or "12,500.50". Hand-rolled rather than a package — none
/// well-maintained exist for this narrow need.
///
/// Tries digits first (most speech engines transcribe numbers as digits by
/// default), falling back to a small ones/teens/tens/hundred/thousand word
/// table for fully spelled-out numbers. Returns `null` if nothing parseable
/// is found.
double? parseSpokenAmount(String text) {
  final normalized = text.toLowerCase().trim();
  if (normalized.isEmpty) return null;

  final digitMatch = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(normalized);
  if (digitMatch != null) {
    final parsed = parseAmount(digitMatch.group(0)!);
    if (parsed != null) return parsed;
  }

  final words = normalized
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return _wordsToNumber(words);
}

double? _wordsToNumber(List<String> words) {
  var total = 0;
  var current = 0;
  var matchedAny = false;

  for (final word in words) {
    final onesValue = _ones[word];
    final tensValue = _tens[word];
    if (onesValue != null) {
      current += onesValue;
      matchedAny = true;
    } else if (tensValue != null) {
      current += tensValue;
      matchedAny = true;
    } else if (word == 'hundred') {
      current = (current == 0 ? 1 : current) * 100;
      matchedAny = true;
    } else if (word == 'thousand') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      matchedAny = true;
    }
    // Unrecognized words (e.g. "pesos", "and") are simply skipped.
  }

  if (!matchedAny) return null;
  return (total + current).toDouble();
}
