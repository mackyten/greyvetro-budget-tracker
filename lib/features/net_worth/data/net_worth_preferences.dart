import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed store (same shape as `MonthDraftStore`) for
/// dashboard-analytics settings — one store, not several near-duplicates,
/// since inflation rate and milestone targets are both small, rarely-changed
/// user preferences.
class NetWorthPreferences {
  NetWorthPreferences._();
  static final instance = NetWorthPreferences._();

  static const _inflationRateKey = 'net_worth_annual_inflation_rate';
  static const _targetsKey = 'net_worth_milestone_targets';
  static const _celebratedTargetsKey = 'net_worth_celebrated_targets';

  Future<double> getAnnualInflationRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_inflationRateKey) ?? 0.0;
  }

  Future<void> setAnnualInflationRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_inflationRateKey, rate);
  }

  Future<List<double>> getTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_targetsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
  }

  Future<void> setTargets(List<double> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetsKey, jsonEncode(targets));
  }

  Future<Set<double>> getCelebratedTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_celebratedTargetsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toSet();
  }

  Future<void> markCelebrated(double target) async {
    final celebrated = await getCelebratedTargets();
    celebrated.add(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_celebratedTargetsKey, jsonEncode(celebrated.toList()));
  }
}
