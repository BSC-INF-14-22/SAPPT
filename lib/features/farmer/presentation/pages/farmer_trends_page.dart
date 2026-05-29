import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';
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
    final language = LanguageService.currentLanguage;
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
                      (crop) => DropdownMenuItem(
                        value: crop,
                        child: Text(_cropName(crop, language)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedCrop = value),
              ),
              const SizedBox(height: 20),
              _buildSummaryCard(selected, currencyFormat, language),
              const SizedBox(height: 24),
              Text(
                _text(language, 'All Field Crops', 'Mbewu Zonse'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...insights.map(
                (item) => _buildCropRow(item, currencyFormat, language),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    CropMarketInsight insight,
    NumberFormat currencyFormat,
    AppLanguage language,
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
              _cropName(insight.cropName, language),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _metric(
              _text(language, 'Trend', 'Kusintha'),
              '${_trendText(insight.trendLabel, language)} (${insight.trendPercent.toStringAsFixed(1)}%)',
              Icons.trending_up,
            ),
            _metric(
              _text(
                language,
                'Predicted future price',
                'Mtengo woyembekezeka',
              ),
              '${currencyFormat.format(insight.predictedNextPrice)}/${insight.unit}',
              Icons.insights,
            ),
            _metric(
              _text(
                language,
                'Recommended best market',
                'Msika wabwino wolimbikitsidwa',
              ),
              _text(
                language,
                '$location at ${currencyFormat.format(insight.bestMarketPrice)}/${insight.unit}',
                '$location pa ${currencyFormat.format(insight.bestMarketPrice)}/${insight.unit}',
              ),
              Icons.storefront,
            ),
            _metric(
              _text(
                language,
                'Fair wholesale sell price',
                'Mtengo woyenera wambiri',
              ),
              '${currencyFormat.format(insight.fairWholesalePrice)}/${insight.unit}',
              Icons.price_check,
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

  Widget _buildCropRow(
    CropMarketInsight insight,
    NumberFormat currencyFormat,
    AppLanguage language,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(_cropName(insight.cropName, language)),
        subtitle: Text(
          _text(
            language,
            '${insight.trendLabel} - best: ${insight.bestMarket}'
                '${insight.bestDistrict.isEmpty ? '' : ', ${insight.bestDistrict}'}',
            '${_trendText(insight.trendLabel, language)} - wabwino: ${insight.bestMarket}'
                '${insight.bestDistrict.isEmpty ? '' : ', ${insight.bestDistrict}'}',
          ),
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
              _text(
                language,
                '/${insight.unit} wholesale',
                '/${insight.unit} wambiri',
              ),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _cropName(String cropName, AppLanguage language) {
    return LanguageService.cropNameForLanguage(cropName, language);
  }

  String _text(AppLanguage language, String english, String chichewa) {
    return language == AppLanguage.chichewa ? chichewa : english;
  }

  String _trendText(String trendLabel, AppLanguage language) {
    if (language != AppLanguage.chichewa) return trendLabel;

    switch (trendLabel) {
      case 'Rising':
        return 'Ikukwera';
      case 'Falling':
        return 'Ikutsika';
      case 'Stable':
        return 'Yokhazikika';
      default:
        return trendLabel;
    }
  }
}
