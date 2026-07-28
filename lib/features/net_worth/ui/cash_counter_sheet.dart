import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';

class _Denomination {
  const _Denomination(this.label, this.value);

  final String label;
  final double value;
}

/// Philippine peso bills and coins. Centavo coins are intentionally omitted
/// (rare in circulation) — add another entry here if that's ever needed.
/// Note the two ₱20 entries share a value but have distinct labels; state is
/// keyed by list index below, so the duplicate value is safe.
const _denominations = <_Denomination>[
  _Denomination('₱1000', 1000),
  _Denomination('₱500', 500),
  _Denomination('₱200', 200),
  _Denomination('₱100', 100),
  _Denomination('₱50', 50),
  _Denomination('₱20 bill', 20),
  _Denomination('₱20 coin', 20),
  _Denomination('₱10 coin', 10),
  _Denomination('₱5 coin', 5),
  _Denomination('₱1 coin', 1),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cash Counter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(onPressed: _clear, child: const Text('Clear')),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _denominations.length; i++)
                  _DenominationRow(
                    denomination: _denominations[i],
                    controller: _qtyControllers[i],
                    subtotal: _qtyAt(i) * _denominations[i].value,
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currencyFormat.format(_total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_total),
                  child: const Text('Use total'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(denomination.label)),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currencyFormat.format(subtotal),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
