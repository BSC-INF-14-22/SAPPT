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
  String _selectedCrop = 'Maize';
  String _timeframe = 'Weekly'; // Daily, Weekly, or Monthly

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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartSection(theme, docs),
                    const SizedBox(height: 32),
                    _buildStatsSection(theme, docs),
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
                    final date = (docs[value.toInt()]['date'] as Timestamp)
                        .toDate();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
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
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: docs.asMap().entries.map((e) {
                final price =
                    double.tryParse(e.value['price'].toString()) ?? 0;
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
              'MK ${highest.toStringAsFixed(0)}',
              Icons.arrow_upward,
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Lowest',
              'MK ${lowest.toStringAsFixed(0)}',
              Icons.arrow_downward,
              Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTrendAlert(theme, firstPrice, lastPrice),
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
            ),
          ),
        ],
      ),
    );
  }
}
