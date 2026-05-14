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
      final snapshot = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by phone: $e');
      return null;
    }
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

  /// Get user stream by UID
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
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
