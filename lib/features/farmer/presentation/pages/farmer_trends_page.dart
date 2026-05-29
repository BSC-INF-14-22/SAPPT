import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/market_analytics_service.dart';

class FarmerTrendsPage extends StatefulWidget {
  const FarmerTrendsPage({super.key});

  @override
  State<FarmerTrendsPage> createState() => _FarmerTrendsPageState();
}

class _FarmerTrendsPageState extends State<FarmerTrendsPage> {
  String? _selectedCrop;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'MK ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Price Trends')),
      body: StreamBuilder<List<CropMarketInsight>>(
        stream: MarketAnalyticsService().watchApprovedPriceInsights(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final insights = snapshot.data ?? [];
          if (insights.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No approved cooperative prices available yet.'),
              ),
            );
          }

          final cropNames = insights.map((item) => item.cropName).toList();
          if (_selectedCrop == null || !cropNames.contains(_selectedCrop)) {
            _selectedCrop = cropNames.first;
          }

          final selected = insights.firstWhere(
            (item) => item.cropName == _selectedCrop,
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Crop',
                  border: OutlineInputBorder(),
                ),
                items: cropNames
                    .map(
                      (crop) =>
                          DropdownMenuItem(value: crop, child: Text(crop)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedCrop = value),
              ),
              const SizedBox(height: 20),
              _buildSummaryCard(selected, currencyFormat),
              const SizedBox(height: 16),
              _buildModelCard(selected),
              const SizedBox(height: 24),
              Text(
                'All Field Crops',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...insights.map((item) => _buildCropRow(item, currencyFormat)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    CropMarketInsight insight,
    NumberFormat currencyFormat,
  ) {
    final location = insight.bestDistrict.isEmpty
        ? insight.bestMarket
        : '${insight.bestMarket}, ${insight.bestDistrict}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.cropName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _metric(
              'Trend',
              '${insight.trendLabel} (${insight.trendPercent.toStringAsFixed(1)}%)',
              Icons.trending_up,
            ),
            _metric(
              'Predicted future price',
              '${currencyFormat.format(insight.predictedNextPrice)}/${insight.unit}',
              Icons.insights,
            ),
            _metric(
              'Recommended best market',
              '$location at ${currencyFormat.format(insight.bestMarketPrice)}/${insight.unit}',
              Icons.storefront,
            ),
            _metric(
              'Fair wholesale sell price',
              '${currencyFormat.format(insight.fairWholesalePrice)}/${insight.unit}',
              Icons.price_check,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(CropMarketInsight insight) {
    return Card(
      color: Colors.blue.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Models Used',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Trend model: ${insight.trendModel}.'),
            Text('Prediction model: ${insight.predictionModel}.'),
            Text('Fair wholesale model: ${insight.fairPriceModel}.'),
            const SizedBox(height: 8),
            Text(
              'Sample size: ${insight.sampleSize} approved cooperative price reports.',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropRow(CropMarketInsight insight, NumberFormat currencyFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(insight.cropName),
        subtitle: Text(
          '${insight.trendLabel} - best: ${insight.bestMarket}'
          '${insight.bestDistrict.isEmpty ? '' : ', ${insight.bestDistrict}'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(insight.fairWholesalePrice),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '/${insight.unit} wholesale',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
