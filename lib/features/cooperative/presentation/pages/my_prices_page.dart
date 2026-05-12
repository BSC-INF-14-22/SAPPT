import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';

class MyPricesPage extends StatelessWidget {
  const MyPricesPage({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Submissions')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().getFilteredCollectionStream(
          'prices',
          'uploadedBy',
          user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_edu_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text("You haven't submitted any prices yet."),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _buildMyPriceCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildMyPriceCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);
    final cropName = data['cropName'] ?? 'Unknown';
    final price = data['price'] ?? '0';
    final market = data['market'] ?? 'Local';
    final status = data['status'] ?? 'pending';

    final canEdit = status == 'pending' || status == 'approved';
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_outlined;
    }

    String formattedDate = 'Recent';
    if (data['updatedAt'] != null) {
      if (data['updatedAt'] is Timestamp) {
        formattedDate = DateFormat(
          'MMM d, yyyy',
        ).format((data['updatedAt'] as Timestamp).toDate());
      }
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Text(
              cropName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'MK $price | $market',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Submitted: $formattedDate',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Icon(
          canEdit ? Icons.edit_outlined : Icons.chevron_right,
          color: canEdit ? theme.primaryColor : Colors.grey,
        ),
        onTap: canEdit
            ? () => Navigator.pushNamed(
                context,
                '/edit-price',
                arguments: {'docId': docId, 'data': data},
              )
            : null,
      ),
    );
  }
}
