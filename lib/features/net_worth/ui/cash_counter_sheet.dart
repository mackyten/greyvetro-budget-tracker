import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';

class _Denomination {
  const _Denomination(this.label, this.value, this.type);

  final String label;
  final double value;
  final String type;
}

/// Philippine peso bills and coins. Centavo coins are intentionally omitted
/// (rare in circulation) — add another entry here if that's ever needed.
/// Note the two ₱20 entries share a value but have distinct labels; state is
/// keyed by list index below, so the duplicate value is safe.
const _denominations = <_Denomination>[
  _Denomination('₱1000', 1000, 'Bill'),
  _Denomination('₱500', 500, 'Bill'),
  _Denomination('₱200', 200, 'Bill'),
  _Denomination('₱100', 100, 'Bill'),
  _Denomination('₱50', 50, 'Bill'),
  _Denomination('₱20', 20, 'Bill'),
  _Denomination('₱20', 20, 'Coin'),
  _Denomination('₱10', 10, 'Coin'),
  _Denomination('₱5', 5, 'Coin'),
  _Denomination('₱1', 1, 'Coin'),
];

/// A standalone denomination calculator: enter how many of each bill/coin
/// you have and it sums the total, so it never needs to know about
/// [Account] or persist anything — the caller reads the result off
/// [Navigator.pop] and decides what to do with it.
class CashCounterSheet extends StatefulWidget {
  const CashCounterSheet({super.key});

  @override
  State<CashCounterSheet> createState() => _CashCounterSheetState();
}

class _CashCounterSheetState extends State<CashCounterSheet> {
  late final List<TextEditingController> _qtyControllers;

  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    _qtyControllers = [for (final _ in _denominations) TextEditingController()];
    for (final c in _qtyControllers) {
      c.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final c in _qtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _qtyAt(int index) => int.tryParse(_qtyControllers[index].text) ?? 0;

  double get _total {
    var sum = 0.0;
    for (var i = 0; i < _denominations.length; i++) {
      sum += _qtyAt(i) * _denominations[i].value;
    }
    return sum;
  }

  void _clear() {
    for (final c in _qtyControllers) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cash counter',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: uiFont,
                        color: palette.heading,
                      ),
                    ),
                    TextButton(
                      onPressed: _clear,
                      style: TextButton.styleFrom(foregroundColor: AppPalette.blueDeep),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _denominations.length; i++)
                          _DenominationRow(
                            denomination: _denominations[i],
                            controller: _qtyControllers[i],
                            subtotal: _qtyAt(i) * _denominations[i].value,
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: uiFont,
                          color: palette.heading,
                        ),
                      ),
                      Text(
                        currencyFormat.format(_total),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: monoFont,
                          color: palette.heading,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: palette.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: palette.heading,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(_total),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: AppPalette.blueDeep,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Use total'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DenominationRow extends StatelessWidget {
  const _DenominationRow({
    required this.denomination,
    required this.controller,
    required this.subtotal,
  });

  final _Denomination denomination;
  final TextEditingController controller;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  denomination.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: monoFont,
                    color: palette.heading,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    denomination.type,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: uiFont,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 13, fontFamily: uiFont, color: palette.heading),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              currencyFormat.format(subtotal),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.text),
            ),
          ),
        ],
      ),
    );
  }
}
