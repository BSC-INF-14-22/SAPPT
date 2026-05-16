import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FarmerTrendsPage extends StatefulWidget {
  const FarmerTrendsPage({super.key});

  @override
  State<FarmerTrendsPage> createState() => _FarmerTrendsPageState();
}

class _FarmerTrendsPageState extends State<FarmerTrendsPage> {
<<<<<<< HEAD
  String _selectedCrop = 'Maize';
  String _timeframe = 'Weekly'; // Daily, Weekly, or Monthly

=======
  String? _selectedCrop;
  String _timeframe = 'Weekly'; // Weekly or Monthly
  
>>>>>>> BSC-INF-15-21
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Price Trends')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectors(theme),
            const SizedBox(height: 32),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('price_history')
                  .where('cropName', isEqualTo: _selectedCrop)
<<<<<<< HEAD
                  .orderBy('date', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data?.docs ?? [];
                
                DateTime now = DateTime.now();
                DateTime startDate;
                switch (_timeframe) {
                  case 'Daily':
                    startDate = now.subtract(const Duration(days: 7)); // Last 7 days
                    break;
                  case 'Monthly':
                    startDate = DateTime(now.year, now.month - 6, now.day); // Last 6 months
                    break;
                  case 'Weekly':
                  default:
                    startDate = now.subtract(const Duration(days: 30)); // Last 4 weeks
                    break;
                }

                final docs = allDocs.where((doc) {
                  if (doc.data().containsKey('date') && doc['date'] != null) {
                    final date = (doc['date'] as Timestamp).toDate();
                    return date.isAfter(startDate);
                  }
                  return false;
                }).toList();
=======
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Sort in-memory to avoid composite index requirement
                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
                docs.sort((a, b) {
                  final aTime = a.data()['date'] as Timestamp?;
                  final bTime = b.data()['date'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return aTime.compareTo(bTime); // Ascending
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text('No historical data available for this crop.'),
                    ),
                  );
                }

                // Calculate Stats
                final prices = docs.map((e) => double.tryParse(e.data()['price'].toString()) ?? 0.0).toList();
                final highest = prices.reduce((a, b) => a > b ? a : b);
                final lowest = prices.reduce((a, b) => a < b ? a : b);
                final projection = _generateProjection(docs);
>>>>>>> BSC-INF-15-21

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
<<<<<<< HEAD
                    _buildChartSection(theme, docs),
                    const SizedBox(height: 32),
                    _buildStatsSection(theme, docs),
=======
                    _buildChart(theme, docs),
                    const SizedBox(height: 32),
                    _buildStatsSection(theme, highest, lowest, projection),
>>>>>>> BSC-INF-15-21
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectors(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
<<<<<<< HEAD
        // Crop Selector
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, snapshot) {
            final productNames = snapshot.data?.docs
                .map((d) => d.data()['name'] as String)
                .toList() ?? [];

            // If list is empty, just show a disabled dropdown or default
            if (productNames.isEmpty) {
              return DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                  labelText: 'Crop',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [],
                onChanged: null,
              );
            }

            // Ensure _selectedCrop is valid
            if (!productNames.contains(_selectedCrop)) {
              _selectedCrop = productNames.first;
            }

            return DropdownButtonFormField<String>(
              value: _selectedCrop,
              decoration: const InputDecoration(
                labelText: 'Crop',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: productNames
                  .map((crop) => DropdownMenuItem(value: crop, child: Text(crop)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCrop = val);
                }
              },
            );
          },
=======
        // Crop Selector (Dynamic from Firestore)
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              final productNames = snapshot.data?.docs
                  .map((d) => d.data()['name'] as String)
                  .toList() ?? [];
              
              productNames.sort();

              if (_selectedCrop == null && productNames.isNotEmpty) {
                _selectedCrop = productNames.first;
              } else if (_selectedCrop != null && !productNames.contains(_selectedCrop)) {
                _selectedCrop = productNames.first;
              }

              return DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Crop Filter',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: productNames.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
                onChanged: (val) => setState(() => _selectedCrop = val),
              );
            },
          ),
>>>>>>> BSC-INF-15-21
        ),
        const SizedBox(height: 16),
        // Timeframe Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: theme.primaryColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeframeButton('Daily'),
                _buildTimeframeButton('Weekly'),
                _buildTimeframeButton('Monthly'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeButton(String label) {
    final isSelected = _timeframe == label;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _timeframe = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildChartSection(ThemeData theme, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: Text('No historical data available for this timeframe.')),
      );
    }

=======
  String _generateProjection(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.length < 3) return 'Collecting more data for accurate projections...';

    final prices = docs.map((d) => double.tryParse(d.data()['price'].toString()) ?? 0.0).toList();
    final dates = docs.map((d) => (d.data()['date'] as Timestamp).toDate()).toList();

    // Simple Linear Regression: y = mx + c
    int n = prices.length;
    double sumX = 0; // days from start
    double sumY = 0; // prices
    double sumXY = 0;
    double sumX2 = 0;

    DateTime startDate = dates.first;
    for (int i = 0; i < n; i++) {
      double x = dates[i].difference(startDate).inDays.toDouble();
      double y = prices[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    double denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) return 'Prices for $_selectedCrop are holding steady.';

    double slope = (n * sumXY - sumX * sumY) / denominator;

    // Predict for next week (7 days after the last data point)
    double lastX = dates.last.difference(startDate).inDays.toDouble();
    double predictionX = lastX + 7;
    double intercept = (sumY - slope * sumX) / n;
    double predictedPrice = slope * predictionX + intercept;

    double lastPrice = prices.last;
    double percentageChange = ((predictedPrice - lastPrice) / lastPrice) * 100;

    String trend = slope > 0 ? 'rise' : 'fall';
    if (slope.abs() < 0.1) return 'Prices for $_selectedCrop are expected to remain stable next week.';

    return 'Prices for $_selectedCrop are projected to $trend by ${percentageChange.abs().toStringAsFixed(1)}% next week based on market velocity.';
  }

  Widget _buildChart(ThemeData theme, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
>>>>>>> BSC-INF-15-21
    return Container(
      height: 300,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < docs.length) {
<<<<<<< HEAD
                    final date = (docs[value.toInt()]['date'] as Timestamp)
                        .toDate();
=======
                    final date = (docs[value.toInt()]['date'] as Timestamp).toDate();
>>>>>>> BSC-INF-15-21
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(date),
<<<<<<< HEAD
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
=======
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
>>>>>>> BSC-INF-15-21
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                reservedSize: 40,
              ),
            ),
<<<<<<< HEAD
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
=======
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
>>>>>>> BSC-INF-15-21
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: docs.asMap().entries.map((e) {
<<<<<<< HEAD
                final price =
                    double.tryParse(e.value['price'].toString()) ?? 0;
=======
                final price = double.tryParse(e.value.data()['price'].toString()) ?? 0;
>>>>>>> BSC-INF-15-21
                return FlSpot(e.key.toDouble(), price);
              }).toList(),
              isCurved: true,
              color: theme.primaryColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: theme.primaryColor.withAlpha(25),
              ),
            ),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildStatsSection(ThemeData theme, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double highest = 0;
    double lowest = double.infinity;
    double firstPrice = 0;
    double lastPrice = 0;

    if (docs.isNotEmpty) {
      firstPrice = double.tryParse(docs.first.data()['price'].toString()) ?? 0;
      lastPrice = double.tryParse(docs.last.data()['price'].toString()) ?? 0;

      for (var doc in docs) {
        final p = double.tryParse(doc.data()['price'].toString()) ?? 0;
        if (p > highest) highest = p;
        if (p < lowest && p > 0) lowest = p;
      }
      if (lowest == double.infinity) lowest = 0;
    } else {
      lowest = 0;
    }

=======
  Widget _buildStatsSection(ThemeData theme, double highest, double lowest, String projection) {
    final currencyFormat = NumberFormat.currency(symbol: 'MK ', decimalDigits: 0);
    
>>>>>>> BSC-INF-15-21
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              'Highest',
<<<<<<< HEAD
              'MK ${highest.toStringAsFixed(0)}',
=======
              currencyFormat.format(highest),
>>>>>>> BSC-INF-15-21
              Icons.arrow_upward,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Lowest',
<<<<<<< HEAD
              'MK ${lowest.toStringAsFixed(0)}',
=======
              currencyFormat.format(lowest),
>>>>>>> BSC-INF-15-21
              Icons.arrow_downward,
              Colors.red,
            ),
          ],
        ),
<<<<<<< HEAD
        const SizedBox(height: 16),
        _buildTrendAlert(theme, firstPrice, lastPrice),
=======
        const SizedBox(height: 24),
        _buildTrendAlert(theme, projection),
>>>>>>> BSC-INF-15-21
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildTrendAlert(ThemeData theme, double firstPrice, double lastPrice) {
    String projectionText = 'Not enough data for projections.';
    IconData icon = Icons.info_outline;
    Color color = Colors.grey;

    if (firstPrice > 0 && lastPrice > 0) {
      final change = ((lastPrice - firstPrice) / firstPrice) * 100;
      if (change > 0) {
        projectionText = 'Prices for $_selectedCrop have risen by ${change.toStringAsFixed(1)}% over this timeframe. Upward trend detected.';
        icon = Icons.trending_up;
        color = Colors.green;
      } else if (change < 0) {
        projectionText = 'Prices for $_selectedCrop have dropped by ${change.abs().toStringAsFixed(1)}% over this timeframe. Downward trend detected.';
        icon = Icons.trending_down;
        color = Colors.red;
      } else {
        projectionText = 'Prices for $_selectedCrop have remained stable over this timeframe.';
        icon = Icons.trending_flat;
        color = Colors.blue;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              projectionText,
              style: const TextStyle(fontSize: 14),
=======
  Widget _buildTrendAlert(ThemeData theme, String projection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Market Projection',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  projection,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
>>>>>>> BSC-INF-15-21
            ),
          ),
        ],
      ),
    );
  }
}
