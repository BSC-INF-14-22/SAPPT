// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/notification_service.dart';

class PriceApprovalPage extends StatefulWidget {
  const PriceApprovalPage({super.key});

  @override
  State<PriceApprovalPage> createState() => _PriceApprovalPageState();
}

class _PriceApprovalPageState extends State<PriceApprovalPage> {
  final _reasonController = TextEditingController();

  String _slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  void _approvePrice(String docId, Map<String, dynamic> data) async {
    try {
      final cropName = (data['cropName'] ?? data['productName'] ?? 'Unknown')
          .toString()
          .trim();
      final unit = (data['unit'] ?? 'kg').toString().trim();
      final marketName = (data['market'] ?? data['marketName'] ?? 'Local Market')
          .toString()
          .trim();
      final district = (data['district'] ?? '').toString().trim();
      final productId = _slugify(cropName);
      final marketId = (data['marketId'] ?? _slugify('$marketName $district'))
          .toString()
          .trim();

      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'name': cropName,
        'cropName': cropName,
        'unit': unit,
        'measurementUnit': unit,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('commodities').doc(productId).set({
        'name': cropName,
        'cropName': cropName,
        'unit': unit,
        'measurementUnit': unit,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('markets').doc(marketId).set({
        'name': marketName,
        'marketName': marketName,
        'district': district,
        'region': district,
        'location': district.isEmpty ? marketName : district,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirestoreService().updateData('prices', docId, {
        'status': 'approved',
        'cropName': cropName,
        'productName': cropName,
        'unit': unit,
        'market': marketName,
        'marketName': marketName,
        'marketId': marketId,
        'district': district,
        'sourceType': data['sourceType'] ?? 'manual',
        'submittedAt': data['submittedAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 1. Notify the Cooperative Officer that their price was approved
      if (data['uploadedBy'] != null) {
        await NotificationService().sendInAppNotification(
          uid: data['uploadedBy'],
          title: 'Price Approved ✅',
          message:
              'Your submitted price for $cropName has been approved and is now live.',
        );
      }

      // 2. Broadcast to all Farmers that new prices are available
      await NotificationService().sendRoleBroadcast(
        role: 'Farmer',
        title: 'New Market Prices 📈',
        message:
            'New verified prices for $cropName are now available in the market.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price approved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _rejectPrice(String docId, Map<String, dynamic> data) {
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejecting this price entry:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reason is required for rejection.'),
                  ),
                );
                return;
              }
              Navigator.pop(context); // Close dialog
              try {
                await FirestoreService().updateData('prices', docId, {
                  'status': 'rejected',
                  'rejectionReason': _reasonController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Notify the Cooperative Officer about the rejection
                if (data['uploadedBy'] != null) {
                  await NotificationService().sendInAppNotification(
                    uid: data['uploadedBy'],
                    title: 'Price Rejected ❌',
                    message:
                        'Your price for ${data['cropName']} was rejected. Reason: ${_reasonController.text.trim()}',
                  );
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Price rejected.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Approvals')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().getFilteredCollectionStream(
          'prices',
          'status',
          'pending',
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
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text('All caught up! No pending prices.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildPendingCard(doc.id, doc.data());
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingCard(String docId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final cropName = data['cropName'] ?? 'Unknown';
    final price = data['price'] ?? '0';
    final unit = data['unit'] ?? 'kg';
    final market = data['market'] ?? 'Local Market';
    final district = data['district'] ?? 'Not Specified';
    final notes = data['notes'] ?? '';

    String formattedDate = 'Recent';
    if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
      formattedDate = DateFormat(
        'MMM d, yyyy HH:mm',
      ).format((data['updatedAt'] as Timestamp).toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cropName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'MK $price / $unit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.storefront, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('$market, $district'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Submitted: $formattedDate',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(notes, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPrice(docId, data),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePrice(docId, data),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
