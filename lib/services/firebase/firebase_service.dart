import 'dart:developer';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  FirebaseService._();

  /// Initialize Firebase Services and FCM
  static Future<void> initialize() async {
    try {
      // Initialize Firebase core.
      // Note: If you have generated options using 'flutterfire configure',
      // you can pass 'DefaultFirebaseOptions.currentPlatform' here.
      await Firebase.initializeApp();
      log('Firebase initialized successfully.');
      
      // Setup Firebase Cloud Messaging (FCM) — not supported on Windows desktop
      if (!Platform.isWindows) {
        await _setupMessaging();
      } else {
        log('Skipping FCM setup on Windows (not supported).');
      }
    } catch (e) {
      log('Firebase initialization failed (likely due to missing google-services.json/GoogleService-Info.plist). Running in offline mode: $e');
    }
  }


  /// Configure Firebase Cloud Messaging
  static Future<void> _setupMessaging() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notifications permissions
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );

      log('FCM permission authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Fetch the FCM token for notification targeting
        final token = await messaging.getToken();
        log('FCM Registration Token: $token');

        // Handle foreground notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          log('Received a foreground notification: ${message.notification?.title}');
        });

        // Handle notifications that opened the app
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          log('A notification opened the app: ${message.data}');
        });
      }
    } catch (e) {
      log('Failed to configure Firebase Cloud Messaging: $e');
    }
  }
}
