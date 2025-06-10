import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
}

class FCM {
  final _firebaseMessaging = FirebaseMessaging.instance;

  FCM() {
    // Initialize background message handler
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Initialize foreground message handlers
    _initializeForegroundHandlers();
  }

  void _initializeForegroundHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.messageId}');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // You could show a local notification here if needed
      }
    });

    // Handle message when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked: ${message.messageId}');
      // Handle navigation based on message data
    });
  }

  Future<void> getNotificationPermissions() async {
    try {
      // Request permissions with more explicit settings
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');

        // For iOS, get APNS token first
        if (!kIsWeb) {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          print('APNS Token: $apnsToken');

          // Only proceed if we have APNS token on iOS or if we're on Android
          if (apnsToken != null ||
              defaultTargetPlatform == TargetPlatform.android) {
            await _setupFCMToken();
          } else {
            print('Waiting for APNS token...');
            // Retry after a short delay
            await Future.delayed(Duration(seconds: 2));
            await _setupFCMToken();
          }
        } else {
          // Web doesn't need APNS token
          await _setupFCMToken();
        }
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional permission');
        await _setupFCMToken();
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  Future<void> _setupFCMToken() async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        print('FCM Token: $fcmToken');

        // Subscribe to notifications topic
        await _firebaseMessaging.subscribeToTopic('notifications');
        print('Subscribed to notifications topic');

        // Also subscribe to a general topic for all users
        await _firebaseMessaging.subscribeToTopic('all_users');
        print('Subscribed to all_users topic');
      } else {
        print('Failed to get FCM token');
      }
    } catch (e) {
      print('Error setting up FCM token: $e');
    }
  }

  Future<String?> getNotificationToken() async {
    try {
      await _firebaseMessaging.requestPermission();
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        print('FCM Token retrieved: ${fcmToken.substring(0, 20)}...');
        return fcmToken;
      }
      print('Failed to retrieve FCM token');
      return null;
    } catch (e) {
      print('Error getting notification token: $e');
      return null;
    }
  }

  Future<String?> getAPNToken() async {
    try {
      await _firebaseMessaging.requestPermission();
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken != null) {
        print('APNS Token retrieved: ${apnsToken.substring(0, 20)}...');
        return apnsToken;
      }
      print('Failed to retrieve APNS token');
      return null;
    } catch (e) {
      print('Error getting APNS token: $e');
      return null;
    }
  }

  // Method to test notifications
  Future<void> testNotificationSetup() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      print('Notification settings:');
      print('Authorization status: ${settings.authorizationStatus}');
      print('Alert: ${settings.alert}');
      print('Badge: ${settings.badge}');
      print('Sound: ${settings.sound}');

      String? token = await _firebaseMessaging.getToken();
      print(
          'Current FCM token: ${token != null ? token.substring(0, 20) + "..." : "null"}');
    } catch (e) {
      print('Error testing notification setup: $e');
    }
  }
}
