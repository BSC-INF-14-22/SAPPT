// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// removed unused import

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  // Toggles for chart types
  bool _isDailySubmissionsLineChart = false;
  bool _isTopCropsLineChart = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('System Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Demographics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildUsersByRoleChart(theme),

            const SizedBox(height: 32),
            _buildSectionHeader(
              'Activity: Daily Price Submissions',
              theme,
              _isDailySubmissionsLineChart,
              (val) => setState(() => _isDailySubmissionsLineChart = val),
            ),
            const SizedBox(height: 16),
            _buildDailySubmissionsChart(theme),

            const SizedBox(height: 32),
            _buildSectionHeader(
              'Search Trends: Top Crops',
              theme,
              _isTopCropsLineChart,
              (val) => setState(() => _isTopCropsLineChart = val),
            ),
            const SizedBox(height: 16),
            _buildTopCropsSearchedChart(theme),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    ThemeData theme,
    bool isLineChart,
    Function(bool) onToggle,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.bar_chart, size: 20, color: Colors.grey),
            Switch(
              value: isLineChart,
              onChanged: onToggle,
              activeThumbColor: theme.primaryColor,
            ),
            const Icon(Icons.show_chart, size: 20, color: Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildUsersByRoleChart(ThemeData theme) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          int farmers = 0;
          int officers = 0;
          int admins = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final role = data['role'] ?? 'Farmer';
              if (role == 'Farmer') {
                farmers++;
              } else if (role == 'Cooperative Officer') {
                officers++;
              } else if (role == 'Admin') {
                admins++;
              }
            }
          }

          final total = farmers + officers + admins;
          if (total == 0) {
            return const Center(child: Text('No user data available'));
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: farmers.toDouble(),
                        title:
                            '${((farmers / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.orange,
                        value: officers.toDouble(),
                        title:
                            '${((officers / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.red,
                        value: admins.toDouble(),
                        title:
                            '${((admins / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Farmers', Colors.green),
                    const SizedBox(height: 8),
                    _buildLegendItem('Officers', Colors.orange),
                    const SizedBox(height: 8),
                    _buildLegendItem('Admins', Colors.red),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDailySubmissionsChart(ThemeData theme) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('prices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No submission data'));
          }

          Map<int, int> submissionsByDay = {
            1: 0,
            2: 0,
            3: 0,
            4: 0,
            5: 0,
            6: 0,
            7: 0,
          };

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final updatedAt = data['updatedAt'];
            if (updatedAt is Timestamp) {
              final date = updatedAt.toDate();
              submissionsByDay[date.weekday] =
                  (submissionsByDay[date.weekday] ?? 0) + 1;
            }
          }

          final maxY =
              submissionsByDay.values
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              5;

          final titlesData = FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  final index = value.toInt() - 1;
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          );

          if (_isDailySubmissionsLineChart) {
            return LineChart(
              LineChartData(
                minX: 1,
                maxX: 7,
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: titlesData,
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: submissionsByDay.entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                        )
                        .toList(),
                    isCurved: true,
                    color: theme.primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.primaryColor.withAlpha(50),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: titlesData,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: submissionsByDay.entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        color: theme.primaryColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTopCropsSearchedChart(ThemeData theme) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('prices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No price data available for analytics.'),
            );
          }

          // Aggregate crop submissions
          Map<String, int> cropCounts = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final crop = data['cropName'] as String? ?? 'Unknown';
            cropCounts[crop] = (cropCounts[crop] ?? 0) + 1;
          }

          // Sort and take top 5
          final sortedCrops = cropCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final topCrops = sortedCrops.take(5).toList();

          if (topCrops.isEmpty) {
            return const Center(
              child: Text('Insufficient data for crop trends.'),
            );
          }

          final maxY =
              topCrops
                  .map((e) => e.value)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              2;

          final titlesData = FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= topCrops.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      topCrops[index].key,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          );

          return Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Most Active Crops',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isTopCropsLineChart
                    ? LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (topCrops.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxY,
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          titlesData: titlesData,
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(topCrops.length, (index) {
                                return FlSpot(
                                  index.toDouble(),
                                  topCrops[index].value.toDouble(),
                                );
                              }),
                              isCurved: true,
                              color: Colors.orange,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.orange.withAlpha(50),
                              ),
                            ),
                          ],
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: titlesData,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(topCrops.length, (index) {
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: topCrops[index].value.toDouble(),
                                  color: Colors.orange,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(13),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
