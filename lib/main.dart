import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/net_worth/data/budget_repository.dart';
import 'features/net_worth/data/firestore_budget_repository.dart';
import 'features/net_worth/data/seed_importer.dart';
import 'features/net_worth/ui/month_list_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final repository = FirestoreBudgetRepository();
  await importSeedIfEmpty(repository);

  runApp(BudgetTrackerApp(repository: repository));
}

class BudgetTrackerApp extends StatelessWidget {
  const BudgetTrackerApp({super.key, required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greyvetro Budget Tracker',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3E9AC4),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF8FD0E8),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MonthListScreen(repository: repository),
    );
  }
}
