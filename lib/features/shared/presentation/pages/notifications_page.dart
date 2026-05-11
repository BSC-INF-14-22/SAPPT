import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  void _markAsRead(String docId) {
    FirestoreService().updateData('notifications', docId, {'readStatus': true});
  }

  void _markAllAsRead(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      if (doc['readStatus'] == false) {
        _markAsRead(doc.id);
      }
    }
  }

  void _showNotificationDetail(BuildContext context, String title, String message, String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const Divider(height: 32),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in to view notifications.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Error loading notifications: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }

          // Sort in-memory to avoid composite index requirement
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No new notifications', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final unreadCount = docs.where((d) => d['readStatus'] == false).length;

          return Column(
            children: [
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You have $unreadCount unread ${unreadCount == 1 ? 'message' : 'messages'}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                      TextButton(
                        onPressed: () => _markAllAsRead(docs),
                        child: const Text('Mark all as read'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _buildNotificationItem(context, doc.id, data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String docId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final isRead = data['readStatus'] ?? false;
    
    String formattedDate = 'Just now';
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      formattedDate = DateFormat('MMM d, h:mm a').format((data['createdAt'] as Timestamp).toDate());
    }

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        FirestoreService().deleteData('notifications', docId);
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isRead ? Colors.grey[200] : theme.primaryColor.withAlpha(30),
              child: Icon(
                Icons.notifications,
                color: isRead ? Colors.grey : theme.primaryColor,
              ),
            ),
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[800] : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(message, style: TextStyle(color: isRead ? Colors.grey[600] : Colors.black87)),
            const SizedBox(height: 4),
            Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
          onPressed: () => FirestoreService().deleteData('notifications', docId),
          tooltip: 'Delete notification',
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(docId);
          }
          _showNotificationDetail(context, title, message, formattedDate);
        },
      ),
    );
  }
}
