import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icem_bus/config/constants/app_constants.dart';

/// Provider for StorageService, to be overridden in main.dart after SharedPreferences initializes
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

class StorageService {
  final SharedPreferences _sharedPreferences;

  StorageService(this._sharedPreferences);

  /// Check if the onboarding has been completed
  bool get isOnboardingCompleted {
    return _sharedPreferences.getBool(AppConstants.onboardingCompletedKey) ?? false;
  }

  /// Mark onboarding as completed
  Future<bool> setOnboardingCompleted(bool completed) async {
    return await _sharedPreferences.setBool(AppConstants.onboardingCompletedKey, completed);
  }

  /// Generic helpers for preferences storage
  String? getString(String key) => _sharedPreferences.getString(key);
  Future<bool> setString(String key, String val) => _sharedPreferences.setString(key, val);

  bool? getBool(String key) => _sharedPreferences.getBool(key);
  Future<bool> setBool(String key, bool val) => _sharedPreferences.setBool(key, val);

  /// Clear all stored data (useful for logout/reset)
  Future<bool> clearAll() async {
    return await _sharedPreferences.clear();
  }
}

// ==========================================
// PREFERENCES & SETTINGS RIVERPOD CONFIG
// ==========================================
class SettingsState {
  final ThemeMode themeMode;
  final String accentColor;
  final String language;
  final bool isCompactDensity;
  final bool notificationsEnabled;
  final bool passExpiryReminderEnabled;
  final bool appUpdatesEnabled;
  final bool newApplicationsEnabled;
  final bool paymentNotificationsEnabled;
  final bool passDecisionNotificationsEnabled;
  final bool systemNotificationsEnabled;

  const SettingsState({
    required this.themeMode,
    required this.accentColor,
    required this.language,
    this.isCompactDensity = false,
    required this.notificationsEnabled,
    required this.passExpiryReminderEnabled,
    this.appUpdatesEnabled = true,
    this.newApplicationsEnabled = true,
    this.paymentNotificationsEnabled = true,
    this.passDecisionNotificationsEnabled = true,
    this.systemNotificationsEnabled = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? accentColor,
    String? language,
    bool? isCompactDensity,
    bool? notificationsEnabled,
    bool? passExpiryReminderEnabled,
    bool? appUpdatesEnabled,
    bool? newApplicationsEnabled,
    bool? paymentNotificationsEnabled,
    bool? passDecisionNotificationsEnabled,
    bool? systemNotificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      language: language ?? this.language,
      isCompactDensity: isCompactDensity ?? this.isCompactDensity,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      passExpiryReminderEnabled: passExpiryReminderEnabled ?? this.passExpiryReminderEnabled,
      appUpdatesEnabled: appUpdatesEnabled ?? this.appUpdatesEnabled,
      newApplicationsEnabled: newApplicationsEnabled ?? this.newApplicationsEnabled,
      paymentNotificationsEnabled: paymentNotificationsEnabled ?? this.paymentNotificationsEnabled,
      passDecisionNotificationsEnabled: passDecisionNotificationsEnabled ?? this.passDecisionNotificationsEnabled,
      systemNotificationsEnabled: systemNotificationsEnabled ?? this.systemNotificationsEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final storage = ref.watch(storageServiceProvider);
    
    // We schedule firestore sync after the build completes
    Future.microtask(() => _syncFromFirestore());

    return SettingsState(
      themeMode: _parseThemeMode(storage.getString('themeMode') ?? 'system'),
      accentColor: storage.getString('accentColor') ?? 'crimson',
      language: storage.getString('language') ?? 'english',
      isCompactDensity: storage.getBool('isCompactDensity') ?? false,
      notificationsEnabled: storage.getBool('notificationsEnabled') ?? true,
      passExpiryReminderEnabled: storage.getBool('passExpiryReminderEnabled') ?? true,
      appUpdatesEnabled: storage.getBool('appUpdatesEnabled') ?? true,
      newApplicationsEnabled: storage.getBool('newApplicationsEnabled') ?? true,
      paymentNotificationsEnabled: storage.getBool('paymentNotificationsEnabled') ?? true,
      passDecisionNotificationsEnabled: storage.getBool('passDecisionNotificationsEnabled') ?? true,
      systemNotificationsEnabled: storage.getBool('systemNotificationsEnabled') ?? true,
    );
  }

  static ThemeMode _parseThemeMode(String val) {
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('preferences')) {
        final prefs = doc.data()!['preferences'] as Map<String, dynamic>;
        
        final theme = prefs['themeMode'] as String? ?? 'system';
        final accent = prefs['accentColor'] as String? ?? 'crimson';
        final lang = prefs['language'] as String? ?? 'english';
        final compact = prefs['isCompactDensity'] as bool? ?? false;
        final notif = prefs['notificationsEnabled'] as bool? ?? true;
        final expiry = prefs['passExpiryReminderEnabled'] as bool? ?? true;
        final appUp = prefs['appUpdatesEnabled'] as bool? ?? true;
        final newApp = prefs['newApplicationsEnabled'] as bool? ?? true;
        final payNotif = prefs['paymentNotificationsEnabled'] as bool? ?? true;
        final decNotif = prefs['passDecisionNotificationsEnabled'] as bool? ?? true;
        final sysNotif = prefs['systemNotificationsEnabled'] as bool? ?? true;

        state = SettingsState(
          themeMode: _parseThemeMode(theme),
          accentColor: accent,
          language: lang,
          isCompactDensity: compact,
          notificationsEnabled: notif,
          passExpiryReminderEnabled: expiry,
          appUpdatesEnabled: appUp,
          newApplicationsEnabled: newApp,
          paymentNotificationsEnabled: payNotif,
          passDecisionNotificationsEnabled: decNotif,
          systemNotificationsEnabled: sysNotif,
        );

        final storage = ref.read(storageServiceProvider);
        await storage.setString('themeMode', theme);
        await storage.setString('accentColor', accent);
        await storage.setString('language', lang);
        await storage.setBool('isCompactDensity', compact);
        await storage.setBool('notificationsEnabled', notif);
        await storage.setBool('passExpiryReminderEnabled', expiry);
        await storage.setBool('appUpdatesEnabled', appUp);
        await storage.setBool('newApplicationsEnabled', newApp);
        await storage.setBool('paymentNotificationsEnabled', payNotif);
        await storage.setBool('passDecisionNotificationsEnabled', decNotif);
        await storage.setBool('systemNotificationsEnabled', sysNotif);
      }
    } catch (_) {}
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final str = mode.toString().split('.').last;
    state = state.copyWith(themeMode: mode);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('themeMode', str);
    await _syncToFirestore();
  }

  Future<void> updateCompactDensity(bool val) async {
    state = state.copyWith(isCompactDensity: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('isCompactDensity', val);
    await _syncToFirestore();
  }

  Future<void> updateAccentColor(String color) async {
    state = state.copyWith(accentColor: color);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('accentColor', color);
    await _syncToFirestore();
  }

  Future<void> updateLanguage(String lang) async {
    state = state.copyWith(language: lang);
    final storage = ref.read(storageServiceProvider);
    await storage.setString('language', lang);
    await _syncToFirestore();
  }

  Future<void> updateNotificationsEnabled(bool val) async {
    state = state.copyWith(notificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('notificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePassExpiryReminderEnabled(bool val) async {
    state = state.copyWith(passExpiryReminderEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('passExpiryReminderEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateAppUpdatesEnabled(bool val) async {
    state = state.copyWith(appUpdatesEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('appUpdatesEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateNewApplicationsEnabled(bool val) async {
    state = state.copyWith(newApplicationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('newApplicationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePaymentNotificationsEnabled(bool val) async {
    state = state.copyWith(paymentNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('paymentNotificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updatePassDecisionNotificationsEnabled(bool val) async {
    state = state.copyWith(passDecisionNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('passDecisionNotificationsEnabled', val);
    await _syncToFirestore();
  }

  Future<void> updateSystemNotificationsEnabled(bool val) async {
    state = state.copyWith(systemNotificationsEnabled: val);
    final storage = ref.read(storageServiceProvider);
    await storage.setBool('systemNotificationsEnabled', val);
    await _syncToFirestore();
  }

  /// Safe local cache clear: resets non-essential cached keys in SharedPreferences
  Future<void> clearLocalCache() async {
    final storage = ref.read(storageServiceProvider);
    // Remove transient preferences while maintaining basic onboarding state
    await storage.setBool('appUpdatesEnabled', true);
    await storage.setBool('newApplicationsEnabled', true);
    await storage.setBool('paymentNotificationsEnabled', true);
    await storage.setBool('passDecisionNotificationsEnabled', true);
    await storage.setBool('systemNotificationsEnabled', true);
    state = state.copyWith(
      appUpdatesEnabled: true,
      newApplicationsEnabled: true,
      paymentNotificationsEnabled: true,
      passDecisionNotificationsEnabled: true,
      systemNotificationsEnabled: true,
    );
  }

  Future<void> syncPreferences() async {
    await _syncFromFirestore();
    await _syncToFirestore();
  }

  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final themeStr = state.themeMode.toString().split('.').last;
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferences': {
          'themeMode': themeStr,
          'accentColor': state.accentColor,
          'language': state.language,
          'isCompactDensity': state.isCompactDensity,
          'notificationsEnabled': state.notificationsEnabled,
          'passExpiryReminderEnabled': state.passExpiryReminderEnabled,
          'appUpdatesEnabled': state.appUpdatesEnabled,
          'newApplicationsEnabled': state.newApplicationsEnabled,
          'paymentNotificationsEnabled': state.paymentNotificationsEnabled,
          'passDecisionNotificationsEnabled': state.passDecisionNotificationsEnabled,
          'systemNotificationsEnabled': state.systemNotificationsEnabled,
        }
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
