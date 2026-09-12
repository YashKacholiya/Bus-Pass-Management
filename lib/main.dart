import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icem_bus/app/app.dart';
import 'package:icem_bus/services/firebase/firebase_service.dart';
import 'package:icem_bus/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure widget binding is initialized before asynchronous service calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences local cache
  final sharedPreferences = await SharedPreferences.getInstance();
  final storageService = StorageService(sharedPreferences);

  // Initialize Firebase Core & Messaging (Gracefully runs offline if config files are not present)
  await FirebaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const MyApp(),
    ),
  );
}
