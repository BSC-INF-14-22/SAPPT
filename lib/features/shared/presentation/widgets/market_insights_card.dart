import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/market_analytics_service.dart';

class MarketInsightsCard extends StatelessWidget {
  const MarketInsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: 'MK ',
      decimalDigits: 0,
    );

    return StreamBuilder<List<CropMarketInsight>>(
      stream: MarketAnalyticsService().watchApprovedPriceInsights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final insights = snapshot.data ?? [];
        if (insights.isEmpty) return const SizedBox.shrink();

        final best = [...insights]
          ..sort((a, b) => b.bestMarketPrice.compareTo(a.bestMarketPrice));
        final top = best.first;
        final location = top.bestDistrict.isEmpty
            ? top.bestMarket
            : '${top.bestMarket}, ${top.bestDistrict}';

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
                Text(
                  '${top.cropName} has the strongest current market: '
                  '${currencyFormat.format(top.bestMarketPrice)}/${top.unit} '
                  'at $location.',
                  style: const TextStyle(height: 1.45, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  'Trend: ${top.trendLabel} '
                  '(${top.trendPercent.toStringAsFixed(1)}%). '
                  'Predicted next price: '
                  '${currencyFormat.format(top.predictedNextPrice)}/${top.unit}.',
                  style: const TextStyle(height: 1.45, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  'Fair wholesale selling price: '
                  '${currencyFormat.format(top.fairWholesalePrice)}/${top.unit}.',
                  style: const TextStyle(
                    height: 1.45,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Models: ${top.trendModel}; ${top.predictionModel}; '
                  '${top.fairPriceModel}.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
