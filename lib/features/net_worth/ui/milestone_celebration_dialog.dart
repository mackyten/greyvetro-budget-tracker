import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Simple celebratory `AlertDialog` shown once per target the first time
/// net savings crosses it (see `app_shell.dart`'s launch-check hook).
Future<void> showMilestoneCelebrationDialog(BuildContext context, double target) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🎉 Milestone reached!'),
      content: Text('Your net savings passed ${currencyFormat.format(target)}.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice!'),
        ),
      ],
    ),
  );
}
