package com.greyvetro.vetro_ledger

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Renders the home-screen net worth widget from data staged by
// lib/features/net_worth/data/home_widget_sync.dart via
// HomeWidget.saveWidgetData (keys: net_worth_value, net_worth_month).
class NetWorthWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.net_worth_widget_layout).apply {
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.net_worth_widget_container, pendingIntent)

            setTextViewText(
                R.id.net_worth_widget_value,
                widgetData.getString("net_worth_value", null) ?: "—",
            )
            val month = widgetData.getString("net_worth_month", null)
            setTextViewText(
                R.id.net_worth_widget_month,
                if (month != null) "As of $month" else "Open the app to sync",
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
