import 'package:flutter_test/flutter_test.dart';

import 'package:vetro_ledger/features/net_worth/ui/voice_amount_parser.dart';

void main() {
  group('parseSpokenAmount — digit path', () {
    test('plain digits', () {
      expect(parseSpokenAmount('12500'), 12500);
    });

    test('comma-grouped digits with a currency word', () {
      expect(parseSpokenAmount('12,500 pesos'), 12500);
    });

    test('digits with a decimal point', () {
      expect(parseSpokenAmount('1234.56'), 1234.56);
    });
  });

  group('parseSpokenAmount — spelled-out word path', () {
    test('simple two-digit number', () {
      expect(parseSpokenAmount('twenty five'), 25);
    });

    test('thousands with hundreds', () {
      expect(parseSpokenAmount('twelve thousand five hundred pesos'), 12500);
    });

    test('"a hundred" / "a thousand" phrasing', () {
      expect(parseSpokenAmount('a hundred'), 100);
      expect(parseSpokenAmount('a thousand'), 1000);
    });

    test('large combined amount', () {
      expect(parseSpokenAmount('twenty five thousand three hundred'), 25300);
    });

    test('teens', () {
      expect(parseSpokenAmount('seventeen'), 17);
    });

    test('filler words like "and" are ignored', () {
      expect(parseSpokenAmount('one thousand and fifty'), 1050);
    });
  });

  group('parseSpokenAmount — unparseable input', () {
    test('empty string', () {
      expect(parseSpokenAmount(''), isNull);
    });

    test('no recognizable number words', () {
      expect(parseSpokenAmount('hello there'), isNull);
    });
  });
}
