import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  /// Generic method to update data in a collection
  Future<void> updateData(String collection, String docId, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(docId).update(data);
  }

  /// Generic method to add data to a collection (random ID)
  Future<void> addData(String collection, Map<String, dynamic> data) async {
    try {
      await _db.collection(collection).add(data);
      debugPrint('Data added to $collection successfully');
    } catch (e) {
      debugPrint('Error adding data to $collection: $e');
      rethrow;
    }
  }

  /// Generic method to delete data from a collection
  Future<void> deleteData(String collection, String docId) async {
    try {
      await _db.collection(collection).doc(docId).delete();
      debugPrint('Data deleted from $collection successfully');
    } catch (e) {
      debugPrint('Error deleting data from $collection: $e');
      rethrow;
    }
  }

  /// Generic method to set data for a specific document ID
  Future<void> setData(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _db.collection(collection).doc(docId).set(data);
      debugPrint('Data set for $collection/$docId successfully');
    } catch (e) {
      debugPrint('Error setting data for $collection/$docId: $e');
      rethrow;
    }
  }

  /// Generic method to get all documents from a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getCollectionStream(String collection) {
    return _db.collection(collection).snapshots();
  }

  /// Generic method to get filtered documents from a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getFilteredCollectionStream(
    String collection, 
    String field, 
    dynamic value
  ) {
    return _db.collection(collection).where(field, isEqualTo: value).snapshots();
  }

  /// Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      const phoneFields = ['phone', 'phoneNumber', 'mobile', 'normalizedPhone'];
      for (final phoneVariant in phoneLookupVariants(phone)) {
        for (final field in phoneFields) {
          final snapshot = await _db
              .collection('users')
              .where(field, isEqualTo: phoneVariant)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            return snapshot.docs.first.data();
          }
        }
      }

      final targetKeys = phoneComparisonKeys(phone);
      final usersSnapshot = await _db.collection('users').limit(500).get();
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final savedPhone = data['phone'] ??
            data['phoneNumber'] ??
            data['mobile'] ??
            data['normalizedPhone'];

        if (savedPhone == null) continue;
        final savedKeys = phoneComparisonKeys(savedPhone.toString());
        if (targetKeys.intersection(savedKeys).isNotEmpty) {
          return data;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting user by phone: $e');
      return null;
    }
  }

  Future<String?> getEmailByPhone(String phone) async {
    try {
      for (final phoneKey in phoneComparisonKeys(phone)) {
        final doc = await _db.collection('phone_login').doc(phoneKey).get();
        final email = doc.data()?['email'];
        if (email is String && email.trim().isNotEmpty) {
          return email.trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting login email by phone: $e');
      return null;
    }
  }

  Future<void> setPhoneLoginIndex({
    required String phone,
    required String email,
    required String uid,
  }) async {
    final normalizedPhone = normalizePhoneForStorage(phone);
    if (normalizedPhone.isEmpty) return;

    await _db.collection('phone_login').doc(normalizedPhone).set({
      'email': email.trim(),
      'uid': uid,
      'phone': phone.trim(),
      'normalizedPhone': normalizedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String normalizePhoneForStorage(String phone) {
    final keys = phoneComparisonKeys(phone);
    if (keys.isEmpty) return phone.trim();
    return keys.first;
  }

  static Set<String> phoneComparisonKeys(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final keys = <String>{};

    if (digitsOnly.isEmpty) return keys;

    keys.add(digitsOnly);

    if (digitsOnly.startsWith('00') && digitsOnly.length > 2) {
      keys.add(digitsOnly.substring(2));
    }

    if (digitsOnly.startsWith('265') && digitsOnly.length > 3) {
      final local = digitsOnly.substring(3);
      keys.add(local);
      keys.add('0$local');
      keys.add('265$local');
    } else if (digitsOnly.startsWith('0') && digitsOnly.length > 1) {
      final local = digitsOnly.substring(1);
      keys.add(local);
      keys.add('0$local');
      keys.add('265$local');
    } else if (digitsOnly.length == 9) {
      keys.add('0$digitsOnly');
      keys.add('265$digitsOnly');
    }

    return keys;
  }

  static List<String> phoneLookupVariants(String phone) {
    final trimmed = phone.trim();
    final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digitsOnly = compact.replaceAll(RegExp(r'\D'), '');
    final variants = <String>{trimmed, compact};

    variants.addAll(phoneComparisonKeys(phone));
    variants.addAll(phoneComparisonKeys(phone).map((value) => '+$value'));

    if (digitsOnly.isNotEmpty) {
      variants.add(digitsOnly);
      variants.add('+$digitsOnly');

      if (digitsOnly.startsWith('0') && digitsOnly.length > 1) {
        final withoutLeadingZero = digitsOnly.substring(1);
        variants.add(withoutLeadingZero);
        variants.add('+265$withoutLeadingZero');
        variants.add('265$withoutLeadingZero');
      }

      if (digitsOnly.startsWith('265') && digitsOnly.length > 3) {
        final local = digitsOnly.substring(3);
        variants.add('+$digitsOnly');
        variants.add('0$local');
      }

      if (digitsOnly.startsWith('260') && digitsOnly.length > 3) {
        final local = digitsOnly.substring(3);
        variants.add('+$digitsOnly');
        variants.add('0$local');
      }

      if (digitsOnly.length == 9) {
        variants.add('0$digitsOnly');
        variants.add('+265$digitsOnly');
        variants.add('265$digitsOnly');
      }
    }

    return variants.where((value) => value.isNotEmpty).toList();
  }

  /// Get user by UID (using document ID)
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user by uid: $e');
      return null;
    }
  }

  /// Method to test connection by writing and reading from a test collection
  Future<bool> testConnection() async {
    try {
      const testCollection = '_connection_test_';
      final testData = {
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'connected',
      };

      // Try to write
      final docRef = await _db.collection(testCollection).add(testData);
      
      // Try to read
      final snapshot = await docRef.get();
      
      // Clean up (optional, but good for test collections)
      await docRef.delete();
      
      return snapshot.exists;
    } catch (e) {
      debugPrint('Firestore connection test failed: $e');
      return false;
    }
  }
}
