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
  final Set<String> _selectedPriceIds = {};
  bool _isBulkProcessing = false;

  String _slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  Future<void> _approvePrice(
    String docId,
    Map<String, dynamic> data, {
    bool showFeedback = true,
  }) async {
    try {
      final cropName = (data['cropName'] ?? data['productName'] ?? 'Unknown')
          .toString()
          .trim();
      final unit = (data['unit'] ?? 'kg').toString().trim();
      final marketName =
          (data['market'] ?? data['marketName'] ?? 'Local Market')
              .toString()
              .trim();
      final district = (data['district'] ?? '').toString().trim();
      final productId = _slugify(cropName);
      final marketId = (data['marketId'] ?? _slugify('$marketName $district'))
          .toString()
          .trim();

      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .set({
            'name': cropName,
            'cropName': cropName,
            'unit': unit,
            'measurementUnit': unit,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('commodities')
          .doc(productId)
          .set({
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

      await _notifyFarmersIfBestMarketChanges(
        cropName: cropName,
        productId: productId,
        unit: unit,
      );

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

      if (!mounted || !showFeedback) return;
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

  Future<void> _notifyFarmersIfBestMarketChanges({
    required String cropName,
    required String productId,
    required String unit,
  }) async {
    final prices = await FirebaseFirestore.instance
        .collection('prices')
        .where('status', isEqualTo: 'approved')
        .where('productName', isEqualTo: cropName)
        .get();

    if (prices.docs.isEmpty) return;

    QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
    double bestPrice = 0;

    for (final doc in prices.docs) {
      final price = double.tryParse(doc.data()['price'].toString()) ?? 0;
      if (price > bestPrice) {
        bestPrice = price;
        bestDoc = doc;
      }
    }

    if (bestDoc == null) return;

    final bestData = bestDoc.data();
    final bestMarket = (bestData['market'] ?? bestData['marketName'] ?? '')
        .toString()
        .trim();
    final bestDistrict = (bestData['district'] ?? '').toString().trim();
    final bestMarketId =
        (bestData['marketId'] ?? _slugify('$bestMarket $bestDistrict'))
            .toString()
            .trim();
    final alertRef = FirebaseFirestore.instance
        .collection('market_alerts')
        .doc(productId);
    final previous = await alertRef.get();
    final previousMarketId = previous.data()?['bestMarketId'];

    await alertRef.set({
      'cropName': cropName,
      'bestMarketId': bestMarketId,
      'bestMarket': bestMarket,
      'bestDistrict': bestDistrict,
      'bestPrice': bestPrice,
      'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previous.exists && previousMarketId != bestMarketId) {
      final location = bestDistrict.isEmpty
          ? bestMarket
          : '$bestMarket, $bestDistrict';
      await NotificationService().sendRoleBroadcast(
        role: 'Farmer',
        title: 'Best Market Changed',
        message:
            '$cropName is now strongest at $location: MK ${bestPrice.toStringAsFixed(0)}/$unit.',
      );
    }
  }

  Future<void> _applyRejection(
    String docId,
    Map<String, dynamic> data,
    String reason, {
    bool showFeedback = true,
  }) async {
    await FirestoreService().updateData('prices', docId, {
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (data['uploadedBy'] != null) {
      await NotificationService().sendInAppNotification(
        uid: data['uploadedBy'],
        title: 'Price Rejected',
        message:
            'Your price for ${data['cropName']} was rejected. Reason: $reason',
      );
    }

    if (!mounted || !showFeedback) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Price rejected.'),
        backgroundColor: Colors.red,
      ),
    );
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

  Future<void> _approveSelected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final selectedDocs = docs
        .where((doc) => _selectedPriceIds.contains(doc.id))
        .toList();
    if (selectedDocs.isEmpty) return;

    setState(() => _isBulkProcessing = true);
    try {
      for (final doc in selectedDocs) {
        await _approvePrice(doc.id, doc.data(), showFeedback: false);
      }

      if (!mounted) return;
      setState(() => _selectedPriceIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedDocs.length} price(s) approved.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  void _rejectSelected(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final selectedDocs = docs
        .where((doc) => _selectedPriceIds.contains(doc.id))
        .toList();
    if (selectedDocs.isEmpty) return;

    _reasonController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${selectedDocs.length} Selected Prices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide one reason for rejecting all selected prices:',
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
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reason is required for rejection.'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isBulkProcessing = true);
              try {
                for (final doc in selectedDocs) {
                  await _applyRejection(
                    doc.id,
                    doc.data(),
                    reason,
                    showFeedback: false,
                  );
                }

                if (!mounted) return;
                setState(() => _selectedPriceIds.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${selectedDocs.length} price(s) rejected.'),
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
              } finally {
                if (mounted) setState(() => _isBulkProcessing = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Selected'),
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
          final docIds = docs.map((doc) => doc.id).toSet();
          _selectedPriceIds.removeWhere((id) => !docIds.contains(id));

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

          return Column(
            children: [
              _buildBulkActionBar(docs),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _buildPendingCard(
                      doc.id,
                      doc.data(),
                      isSelected: _selectedPriceIds.contains(doc.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkActionBar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final selectedCount = _selectedPriceIds.length;
    final allSelected = docs.isNotEmpty && selectedCount == docs.length;

    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: _isBulkProcessing
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPriceIds
                                ..clear()
                                ..addAll(docs.map((doc) => doc.id));
                            } else {
                              _selectedPriceIds.clear();
                            }
                          });
                        },
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0
                        ? '${docs.length} pending price(s)'
                        : '$selectedCount selected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _isBulkProcessing || selectedCount == 0
                      ? null
                      : () => setState(() => _selectedPriceIds.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBulkProcessing || selectedCount == 0
                        ? null
                        : () => _rejectSelected(docs),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Reject Selected',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBulkProcessing || selectedCount == 0
                        ? null
                        : () => _approveSelected(docs),
                    icon: _isBulkProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Approve Selected'),
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

  Widget _buildPendingCard(
    String docId,
    Map<String, dynamic> data, {
    required bool isSelected,
  }) {
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
                Checkbox(
                  value: isSelected,
                  onChanged: _isBulkProcessing
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPriceIds.add(docId);
                            } else {
                              _selectedPriceIds.remove(docId);
                            }
                          });
                        },
                ),
                Expanded(
                  child: Text(
                    cropName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
