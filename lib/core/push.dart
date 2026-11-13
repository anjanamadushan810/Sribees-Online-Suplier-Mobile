import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// New-order alerts (FCM, Firebase project sribeesonline). The server sends a push
/// when Sribees approves an order for this supplier, or cancels one it could see.
/// Everything here is best effort: without Firebase (tests, a build without
/// google-services.json) or without the phone's permission, the app works the same
/// and the supplier sees orders on the Orders tab.
class Push {
  static bool _started = false;
  static StreamSubscription<String>? _refresh;

  /// Called once from main() before runApp.
  static Future<void> start() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _started = true;
    } catch (e) {
      debugPrint('Firebase did not start: $e');
    }
  }

  /// After sign-in (and at every app start while signed in): ask once for permission,
  /// then tell the server where to send this supplier's alerts.
  static Future<void> register(Api api) async {
    if (!_started) return;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) await api.registerDevice(token);
      await _refresh?.cancel();
      _refresh = fm.onTokenRefresh.listen((t) => api.registerDevice(t).catchError((_) {}));
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  /// On sign-out: this install stops receiving alerts even if the server never
  /// heard about the sign-out (the server also drops the device with the session).
  static Future<void> unregister() async {
    if (!_started) return;
    try {
      await _refresh?.cancel();
      _refresh = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
