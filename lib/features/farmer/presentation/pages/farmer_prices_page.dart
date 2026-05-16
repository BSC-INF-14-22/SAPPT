import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';

class FarmerPricesPage extends StatefulWidget {
  const FarmerPricesPage({super.key});

  @override
  State<FarmerPricesPage> createState() => _FarmerPricesPageState();
}

class _FarmerPricesPageState extends State<FarmerPricesPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets Overview'),
      ),
      body: Column(
        children: [
          // Search / Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search markets or locations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, productsSnapshot) {
                if (productsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final registeredProducts = productsSnapshot.data?.docs
                    .map((d) => d.data()['name'].toString().toLowerCase())
                    .toSet() ?? {};

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().getFilteredCollectionStream('prices', 'status', 'approved'),
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
                            Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No active markets found.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    // Group data by Market and Location
                    final Map<String, List<Map<String, dynamic>>> marketGroups = {};

                    for (var doc in docs) {
                      final data = doc.data();
                      final cropName = (data['cropName'] ?? '').toString();
                      
                      // Check if crop is registered in 'products' collection
                      if (!registeredProducts.contains(cropName.toLowerCase())) {
                        continue;
                      }

                      final market = (data['market'] ?? 'Unknown Market').toString().trim();
                      final district = (data['district'] ?? 'Not Specified').toString().trim();
                      
                      // Filter by search query
                      if (_searchQuery.isNotEmpty) {
                        if (!market.toLowerCase().contains(_searchQuery) && 
                            !district.toLowerCase().contains(_searchQuery)) {
                          continue;
                        }
                      }

                      final key = '$market|$district';
                      if (!marketGroups.containsKey(key)) {
                        marketGroups[key] = [];
                      }
                      marketGroups[key]!.add(data);
                    }

                    if (marketGroups.isEmpty) {
                      return Center(
                        child: Text('No markets match your criteria.', style: TextStyle(color: Colors.grey[600])),
                      );
                    }

                    final groupedKeys = marketGroups.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: groupedKeys.length,
                      itemBuilder: (context, index) {
                        final key = groupedKeys[index];
                        final parts = key.split('|');
                        final marketName = parts[0];
                        final district = parts[1];
                        final productsList = marketGroups[key]!;

                        return _buildMarketCard(context, marketName, district, productsList);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(BuildContext context, String marketName, String district, List<Map<String, dynamic>> products) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Market Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: Icon(Icons.storefront, color: theme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marketName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(district, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${products.length} Products',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor),
                  ),
                )
              ],
            ),
          ),
          
          // Products List
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: products.map((product) {
                final cropName = product['cropName'] ?? 'Unknown';
                final price = product['price'] ?? '0';
                final unit = product['unit'] ?? 'kg';
                
                String formattedDate = '';
                if (product['updatedAt'] != null) {
                  if (product['updatedAt'] is Timestamp) {
                    formattedDate = DateFormat('MMM d').format((product['updatedAt'] as Timestamp).toDate());
                  } else if (product['updatedAt'] is String) {
                    formattedDate = DateFormat('MMM d').format(DateTime.parse(product['updatedAt']));
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.eco, size: 16, color: Colors.green[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cropName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  if (product['uploadedBy'] != null)
                                    FutureBuilder<Map<String, dynamic>?>(
                                      future: FirestoreService().getUserByUid(product['uploadedBy']),
                                      builder: (context, userSnapshot) {
                                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                                          return const Text('Loading cooperative...', style: TextStyle(fontSize: 11, color: Colors.grey));
                                        }
                                        final coopName = userSnapshot.data?['fullName'] ?? 'Unknown Cooperative';
                                        return Text(
                                          'By: $coopName',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: theme.primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'MK $price / $unit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              'Updated $formattedDate',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
