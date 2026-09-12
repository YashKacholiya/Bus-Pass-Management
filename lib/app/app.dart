import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_theme.dart';

import 'package:icem_bus/services/storage/storage_service.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

    return MaterialApp.router(
      title: 'ICEM Smart Bus Pass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(settings.accentColor, Brightness.light),
      darkTheme: AppTheme.getTheme(settings.accentColor, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: AppRoutes.router,
    );
  }
}
