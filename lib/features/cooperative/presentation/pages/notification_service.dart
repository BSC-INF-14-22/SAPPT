import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize FCM, request permissions, and save the device token
  Future<void> initialize() async {
    // 1. Request permission (required for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      // 2. Get and save token
      await saveTokenToDatabase();

      // 3. Listen to token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _updateTokenInFirestore(newToken);
      });

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
          // Usually handled by flutter_local_notifications if you want a heads-up display
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  /// Saves the FCM token to the user's document
  Future<void> saveTokenToDatabase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  // ==========================================
  // IN-APP NOTIFICATION BUILDERS
  // ==========================================

  /// Sends a targeted in-app notification (e.g., Price Approved/Rejected)
  Future<void> sendInAppNotification({
    required String uid,
    required String title,
    required String message,
  }) async {
    await _db.collection('notifications').add({
      'uid': uid,
      'title': title,
      'message': message,
      'readStatus': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a broadcast notification to all users of a specific role
  Future<void> sendRoleBroadcast({
    required String role,
    required String title,
    required String message,
  }) async {
    // Note: In a production app, writing to thousands of users client-side is inefficient.
    // This should ideally trigger a Cloud Function that handles the fan-out.
    // For this prototype, we will fetch the users and write directly.
    final usersSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: role)
        .get();

    final batch = _db.batch();
    for (var doc in usersSnapshot.docs) {
      final notificationRef = _db.collection('notifications').doc();
      batch.set(notificationRef, {
        'uid': doc.id,
        'title': title,
        'message': message,
        'readStatus': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Global Broadcast (Market Alerts / Announcements)
  Future<void> sendGlobalBroadcast({
    required String title,
    required String message,
  }) async {
    final usersSnapshot = await _db.collection('users').get();

    // Firestore batch limits to 500 operations. We'll chunk it if necessary.
    // Assuming < 500 users for this demo.
    final batch = _db.batch();
    int count = 0;

    for (var doc in usersSnapshot.docs) {
      if (count >= 500) break; // Safety limit for demo
      final notificationRef = _db.collection('notifications').doc();
      batch.set(notificationRef, {
        'uid': doc.id,
        'title': title,
        'message': message,
        'readStatus': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      count++;
    }
    await batch.commit();
  }
}
