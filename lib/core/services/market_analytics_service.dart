import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class PricePoint {
  final String cropName;
  final double price;
  final String unit;
  final String market;
  final String district;
  final DateTime date;

  const PricePoint({
    required this.cropName,
    required this.price,
    required this.unit,
    required this.market,
    required this.district,
    required this.date,
  });
}

class CropMarketInsight {
  final String cropName;
  final String unit;
  final double currentAverage;
  final double fairWholesalePrice;
  final double predictedNextPrice;
  final double trendPercent;
  final String trendLabel;
  final String bestMarket;
  final String bestDistrict;
  final double bestMarketPrice;
  final int sampleSize;
  final String trendModel;
  final String predictionModel;
  final String fairPriceModel;

  const CropMarketInsight({
    required this.cropName,
    required this.unit,
    required this.currentAverage,
    required this.fairWholesalePrice,
    required this.predictedNextPrice,
    required this.trendPercent,
    required this.trendLabel,
    required this.bestMarket,
    required this.bestDistrict,
    required this.bestMarketPrice,
    required this.sampleSize,
    required this.trendModel,
    required this.predictionModel,
    required this.fairPriceModel,
  });
}

class MarketAnalyticsService {
  static const String trendModelName =
      'Ordinary Least Squares linear regression';
  static const String predictionModelName = '7-day linear regression forecast';
  static const String fairPriceModelName =
      '10% trimmed mean plus 12% wholesale profit margin';

  final FirebaseFirestore _db;

  MarketAnalyticsService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Stream<List<CropMarketInsight>> watchApprovedPriceInsights() {
    return _db
        .collection('prices')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snapshot) => buildInsights(snapshot.docs.map((doc) => doc.data())),
        );
  }

  List<CropMarketInsight> buildInsights(
    Iterable<Map<String, dynamic>> rawPrices,
  ) {
    final points =
        rawPrices.map(_pricePointFromMap).whereType<PricePoint>().toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final grouped = <String, List<PricePoint>>{};
    for (final point in points) {
      grouped.putIfAbsent(point.cropName, () => []).add(point);
    }

    final insights =
        grouped.entries
            .map((entry) => _buildCropInsight(entry.key, entry.value))
            .whereType<CropMarketInsight>()
            .toList()
          ..sort((a, b) => a.cropName.compareTo(b.cropName));

    return insights;
  }

  PricePoint? _pricePointFromMap(Map<String, dynamic> data) {
    final cropName = (data['cropName'] ?? data['productName'] ?? '')
        .toString()
        .trim();
    final price = double.tryParse((data['price'] ?? '').toString());
    final unit = (data['unit'] ?? 'kg').toString().trim();
    final market = (data['market'] ?? data['marketName'] ?? 'Local Market')
        .toString()
        .trim();
    final district = (data['district'] ?? '').toString().trim();
    final date = _dateFromValue(
      data['submittedAt'] ?? data['updatedAt'] ?? data['createdAt'],
    );

    if (cropName.isEmpty || price == null || price <= 0) return null;

    return PricePoint(
      cropName: cropName,
      price: price,
      unit: unit.isEmpty ? 'kg' : unit,
      market: market.isEmpty ? 'Local Market' : market,
      district: district,
      date: date,
    );
  }

  CropMarketInsight? _buildCropInsight(String cropName, List<PricePoint> data) {
    if (data.isEmpty) return null;

    final recent = _recentWindow(data);
    final prices = recent.map((point) => point.price).toList();
    final currentAverage = _mean(prices);
    final fairWholesalePrice = _trimmedMean(prices) * 1.12;
    final best = recent.reduce((a, b) => a.price >= b.price ? a : b);
    final regression = _linearRegression(data);
    final latest = data.last;
    final nextX = latest.date.difference(data.first.date).inDays + 7.0;
    final predictedNextPrice = max(
      0,
      regression.intercept + (regression.slope * nextX),
    ).toDouble();
    final trendPercent = latest.price == 0
        ? 0.0
        : ((predictedNextPrice - latest.price) / latest.price) * 100;

    return CropMarketInsight(
      cropName: cropName,
      unit: latest.unit,
      currentAverage: currentAverage,
      fairWholesalePrice: fairWholesalePrice,
      predictedNextPrice: predictedNextPrice,
      trendPercent: trendPercent,
      trendLabel: _trendLabel(trendPercent),
      bestMarket: best.market,
      bestDistrict: best.district,
      bestMarketPrice: best.price,
      sampleSize: data.length,
      trendModel: trendModelName,
      predictionModel: predictionModelName,
      fairPriceModel: fairPriceModelName,
    );
  }

  List<PricePoint> _recentWindow(List<PricePoint> data) {
    final newest = data.last.date;
    final cutoff = newest.subtract(const Duration(days: 30));
    final recent = data.where((point) => point.date.isAfter(cutoff)).toList();
    return recent.isEmpty ? data : recent;
  }

  DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _trimmedMean(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final trimCount = sorted.length >= 10 ? (sorted.length * 0.1).floor() : 0;
    final trimmed = sorted.sublist(trimCount, sorted.length - trimCount);
    return _mean(trimmed.isEmpty ? sorted : trimmed);
  }

  _Regression _linearRegression(List<PricePoint> points) {
    if (points.length < 2) {
      return _Regression(slope: 0, intercept: points.first.price);
    }

    final start = points.first.date;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (final point in points) {
      final x = point.date.difference(start).inDays.toDouble();
      final y = point.price;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final n = points.length;
    final denominator = (n * sumX2) - (sumX * sumX);
    if (denominator == 0) {
      return _Regression(
        slope: 0,
        intercept: _mean(points.map((p) => p.price).toList()),
      );
    }

    final slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    final intercept = (sumY - (slope * sumX)) / n;
    return _Regression(slope: slope, intercept: intercept);
  }

  String _trendLabel(double percent) {
    if (percent.abs() < 2) return 'Stable';
    return percent > 0 ? 'Rising' : 'Falling';
  }
}

class _Regression {
  final double slope;
  final double intercept;

  const _Regression({required this.slope, required this.intercept});
}
