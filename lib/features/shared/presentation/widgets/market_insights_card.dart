import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';
import 'package:smart_agri_price_tracker/core/services/market_analytics_service.dart';

class MarketInsightsCard extends StatefulWidget {
  final AppLanguage language;

  const MarketInsightsCard({
    super.key,
    required this.language,
  });

  @override
  State<MarketInsightsCard> createState() => _MarketInsightsCardState();
}

class _MarketInsightsCardState extends State<MarketInsightsCard> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _startSlideshow();
  }

  void _startSlideshow() {
    Future.delayed(const Duration(seconds: 18), () {
      if (!mounted || !_pageController.hasClients) return;

      final nextPage = (_pageController.page?.round() ?? 0) + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      _startSlideshow();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

        final slides = [...insights]
          ..sort((a, b) => a.cropName.compareTo(b.cropName));

        return Card(
          elevation: 2,
          color: theme.primaryColor.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.primaryColor.withAlpha(50)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) {
                  final insight = slides[index % slides.length];
                  return _InsightSlide(
                    insight: insight,
                    currencyFormat: currencyFormat,
                    color: theme.primaryColor,
                    language: widget.language,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InsightSlide extends StatelessWidget {
  final CropMarketInsight insight;
  final NumberFormat currencyFormat;
  final Color color;
  final AppLanguage language;

  const _InsightSlide({
    required this.insight,
    required this.currencyFormat,
    required this.color,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final location = insight.bestDistrict.isEmpty
        ? insight.bestMarket
        : '${insight.bestMarket}, ${insight.bestDistrict}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_graph, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _text('Market Insight', 'Zokhudza Msika'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          LanguageService.cropNameForLanguage(insight.cropName, language),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _text(
            'Strongest market: ${currencyFormat.format(insight.bestMarketPrice)}/${insight.unit} at $location.',
            'Msika wabwino kwambiri: ${currencyFormat.format(insight.bestMarketPrice)}/${insight.unit} ku $location.',
          ),
          style: const TextStyle(height: 1.45, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          _text(
            'Trend: ${insight.trendLabel} (${insight.trendPercent.toStringAsFixed(1)}%). '
                'Predicted next price: ${currencyFormat.format(insight.predictedNextPrice)}/${insight.unit}.',
            'Kusintha: ${_trendText(insight.trendLabel)} (${insight.trendPercent.toStringAsFixed(1)}%). '
                'Mtengo woyembekezeka wotsatira: ${currencyFormat.format(insight.predictedNextPrice)}/${insight.unit}.',
          ),
          style: const TextStyle(height: 1.45, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          _text(
            'Fair wholesale selling price: ${currencyFormat.format(insight.fairWholesalePrice)}/${insight.unit}.',
            'Mtengo woyenera wogulitsa wambiri: ${currencyFormat.format(insight.fairWholesalePrice)}/${insight.unit}.',
          ),
          style: const TextStyle(
            height: 1.45,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _text(String english, String chichewa) {
    return language == AppLanguage.chichewa ? chichewa : english;
  }

  String _trendText(String trendLabel) {
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
