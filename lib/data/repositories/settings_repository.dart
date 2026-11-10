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
}
