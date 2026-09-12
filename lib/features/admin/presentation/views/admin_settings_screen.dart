import 'package:flutter/material.dart';
import 'package:icem_bus/features/admin/presentation/views/admin_settings_tab.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/bus_logo.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.dividerColor,
          ),
        ),
      ),
      body: const AdminSettingsTab(),
    );
  }
}
