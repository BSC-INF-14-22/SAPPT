import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';

class MarketInsightsCard extends StatelessWidget {
  const MarketInsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, productsSnapshot) {
        if (productsSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final registeredProducts = productsSnapshot.data?.docs
            .map((d) => d.data()['name'].toString().toLowerCase())
            .toSet() ?? {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().getFilteredCollectionStream('prices', 'status', 'approved'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final docs = snapshot.data?.docs.where((doc) {
              final cropName = (doc.data()['cropName'] ?? '').toString();
              return registeredProducts.contains(cropName.toLowerCase());
            }).toList() ?? [];

            if (docs.isEmpty) {
              return const SizedBox.shrink(); // No data to analyze
            }

        // Statistical Model: Premium Variance Analysis
        // Identifies the crop with the highest price premium relative to its own moving average
        Map<String, List<double>> cropPrices = {};
        Map<String, Map<String, dynamic>> bestOffers = {};

        for (var doc in docs) {
          final data = doc.data();
          final crop = data['cropName'] as String? ?? 'Unknown';
          final price = double.tryParse(data['price'].toString()) ?? 0.0;
          
          if (price <= 0) continue;

          if (!cropPrices.containsKey(crop)) {
            cropPrices[crop] = [];
            bestOffers[crop] = data;
          }
          
          cropPrices[crop]!.add(price);

          final currentBestPrice = double.tryParse(bestOffers[crop]!['price'].toString()) ?? 0.0;
          if (price > currentBestPrice) {
            bestOffers[crop] = data;
          }
        }

        if (cropPrices.isEmpty) return const SizedBox.shrink();

        String bestCrop = '';
        double maxPremiumPercentage = -1;
        Map<String, dynamic> topOffer = {};
        double topAvg = 0;

        cropPrices.forEach((crop, prices) {
          final avg = prices.reduce((a, b) => a + b) / prices.length;
          final maxPrice = double.tryParse(bestOffers[crop]!['price'].toString()) ?? 0.0;
          
          if (avg > 0) {
            final premium = ((maxPrice - avg) / avg) * 100;
            // Find the crop that has the highest spike compared to its average
            if (premium > maxPremiumPercentage) {
              maxPremiumPercentage = premium;
              bestCrop = crop;
              topOffer = bestOffers[crop]!;
              topAvg = avg;
            }
          }
        });

        // If no premium exists (all prices are equal), just show the highest absolute price
        if (maxPremiumPercentage <= 0) {
          double highestAbsolute = 0;
          cropPrices.forEach((crop, prices) {
            final maxPrice = double.tryParse(bestOffers[crop]!['price'].toString()) ?? 0.0;
            if (maxPrice > highestAbsolute) {
              highestAbsolute = maxPrice;
              bestCrop = crop;
              topOffer = bestOffers[crop]!;
              topAvg = prices.reduce((a, b) => a + b) / prices.length;
            }
          });
        }

        if (bestCrop.isEmpty) return const SizedBox.shrink();

        final bestPrice = topOffer['price'];
        final unit = topOffer['unit'] ?? 'kg';
        final market = topOffer['market'] ?? 'a local market';
        final district = topOffer['district'] ?? '';
        final location = district.isNotEmpty ? '$market, $district' : market;

        return Card(
          elevation: 2,
          color: theme.primaryColor.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.primaryColor.withAlpha(50)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_graph, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Market Insight',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Best Selling Opportunity: '),
                      TextSpan(
                        text: '$bestCrop ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: 'is currently peaking at '),
                      TextSpan(
                        text: 'MK $bestPrice/$unit ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                      TextSpan(text: 'in $location. This is '),
                      if (maxPremiumPercentage > 0) ...[
                        TextSpan(
                          text: '${maxPremiumPercentage.toStringAsFixed(1)}% higher ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        TextSpan(text: 'than the national average (MK ${topAvg.toStringAsFixed(0)}/$unit).'),
                      ] else ...[
                        const TextSpan(text: 'the current market standard.'),
                      ]
                    ],
                  ),
                  style: const TextStyle(height: 1.5, fontSize: 14),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }
}
