import 'package:home_widget/home_widget.dart';

import '../../../core/format.dart';
import '../models/month_summary.dart';

/// Pushes the latest month's net worth to the Android home-screen widget
/// (`NetWorthWidgetProvider.kt`). Android widgets update on a
/// system-controlled cadence (`updatePeriodMillis` in
/// `net_worth_widget_info.xml`) plus this explicit call — never truly live.
Future<void> updateHomeWidget(MonthSummary latest) async {
  await HomeWidget.saveWidgetData<String>(
    'net_worth_value',
    currencyFormat.format(latest.netSavings),
  );
  await HomeWidget.saveWidgetData<String>(
    'net_worth_month',
    monthFormat.format(latest.entry.month),
  );
  await HomeWidget.updateWidget(androidName: 'NetWorthWidgetProvider');
}
