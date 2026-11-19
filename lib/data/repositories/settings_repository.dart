import 'package:flutter/material.dart';

import '../hive/hive_boxes.dart';

/// App preferences, stored as loose keys in the `settings` box.
class SettingsRepository {
  static const _kSetupComplete = 'setupComplete';
  static const _kThemeMode = 'themeMode';
  static const _kAppLock = 'appLock';

  bool get setupComplete =>
      HiveBoxes.settingsBox.get(_kSetupComplete, defaultValue: false) as bool;

  Future<void> setSetupComplete(bool value) =>
      HiveBoxes.settingsBox.put(_kSetupComplete, value);

  ThemeMode get themeMode {
    final raw =
        HiveBoxes.settingsBox.get(_kThemeMode, defaultValue: 'light') as String;
    return raw == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) => HiveBoxes.settingsBox
      .put(_kThemeMode, mode == ThemeMode.dark ? 'dark' : 'light');

  bool get appLock =>
      HiveBoxes.settingsBox.get(_kAppLock, defaultValue: false) as bool;

  Future<void> setAppLock(bool value) =>
      HiveBoxes.settingsBox.put(_kAppLock, value);

  // ── Reading bank SMS ────────────────────────────────────────────────────

  static const _kSmsEnabled = 'smsEnabled';
  static const _kHandledSms = 'handledSmsIds';
  static const _kLastScan = 'lastSmsScan';

  bool get smsEnabled =>
      HiveBoxes.settingsBox.get(_kSmsEnabled, defaultValue: false) as bool;

  Future<void> setSmsEnabled(bool value) =>
      HiveBoxes.settingsBox.put(_kSmsEnabled, value);

  /// Messages already turned into an entry or skipped, so neither is ever
  /// offered twice.
  Set<String> get handledSmsIds {
    final raw = HiveBoxes.settingsBox.get(_kHandledSms);
    if (raw is! List) return {};
    return raw.cast<String>().toSet();
  }

  Future<void> markSmsHandled(Iterable<String> ids) async {
    // Capped so the list cannot grow without bound on a busy phone. The cap
    // is far above any plausible scan window, and the oldest ids fall off
    // long after their messages have.
    const cap = 2000;
    final merged = <String>[...handledSmsIds, ...ids];
    final trimmed =
        merged.length > cap ? merged.sublist(merged.length - cap) : merged;
    await HiveBoxes.settingsBox.put(_kHandledSms, trimmed);
  }

  /// How far back the next scan should look.
  DateTime get lastSmsScan {
    final millis = HiveBoxes.settingsBox.get(_kLastScan);
    if (millis is! int) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastSmsScan(DateTime when) =>
      HiveBoxes.settingsBox.put(_kLastScan, when.millisecondsSinceEpoch);
}
