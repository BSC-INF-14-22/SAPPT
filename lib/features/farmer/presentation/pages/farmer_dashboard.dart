import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/features/shared/presentation/widgets/market_insights_card.dart';

class FarmerDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const FarmerDashboard({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.languageNotifier,
      builder: (context, language, _) {
        return _buildDashboard(context, language);
      },
    );
  }

  Widget _buildDashboard(BuildContext context, AppLanguage language) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final name = userData['fullName'] ?? _text(language, 'Farmer', 'Mlimi');
    final district =
        userData['district'] ??
        _text(language, 'Not Set', 'Sizinakhazikitsidwe');
    final today = _formatToday(language);

    return Scaffold(
      appBar: AppBar(
        title: Text(_text(language, 'Farmer Dashboard', 'Dashboard ya Mlimi')),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRouter.landing);
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: _text(language, 'Logout', 'Tulukani'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(language, 'Welcome, $name', 'Takulandirani, $name'),
                      style: textTheme.headlineMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          district,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () =>
                      _showProfileDialog(context, name, userData, language),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withAlpha(30),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              today,
              style: textTheme.labelMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Statistical Market Insight
            MarketInsightsCard(language: language),
            const SizedBox(height: 24),

            // Grid of Action Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildDashboardCard(
                  context,
                  _text(language, 'View Prices', 'Onani Mitengo'),
                  Icons.monetization_on_outlined,
                  Colors.green,
                  () => Navigator.pushNamed(context, AppRouter.marketPrices),
                ),
                _buildDashboardCard(
                  context,
                  _text(language, 'Search Crops', 'Sakani Mbewu'),
                  Icons.search_rounded,
                  Colors.blue,
                  () => Navigator.pushNamed(context, AppRouter.searchPrices),
                ),
                _buildDashboardCard(
                  context,
                  _text(language, 'Price Trends', 'Kusintha kwa Mitengo'),
                  Icons.trending_up_rounded,
                  Colors.orange,
                  () => Navigator.pushNamed(context, AppRouter.priceTrends),
                ),
                _buildDashboardCard(
                  context,
                  _text(language, 'Notifications', 'Zidziwitso'),
                  Icons.notifications_active_outlined,
                  Colors.red,
                  () => Navigator.pushNamed(context, AppRouter.notifications),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large Profile Card
            _buildProfileCard(
              context,
              theme,
              language,
              () => _showProfileDialog(context, name, userData, language),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: Color(0xFF2E7D32)),
            label: _text(language, 'Home', 'Kunyumba'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics, color: Color(0xFF2E7D32)),
            label: _text(language, 'Markets', 'Misika'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Color(0xFF2E7D32)),
            label: _text(language, 'Profile', 'Mbiri'),
          ),
        ],
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppRouter.marketPrices);
          } else if (index == 2) {
            _showProfileDialog(context, name, userData, language);
          }
        },
      ),
    );
  }

  void _showProfileDialog(
    BuildContext context,
    String name,
    Map<String, dynamic> userData,
    AppLanguage language,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(language, 'Farmer Profile', 'Mbiri ya Mlimi')),
        content: Text(
          _text(
            language,
            'Name: $name\nRole: Farmer\nDistrict: ${userData['district'] ?? 'Not Set'}\nEmail: ${userData['email'] ?? 'N/A'}',
            'Dzina: $name\nUdindo: Mlimi\nBoma: ${userData['district'] ?? 'Sizinakhazikitsidwe'}\nImelo: ${userData['email'] ?? 'Palibe'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_text(language, 'Close', 'Tsekani')),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ThemeData theme,
    AppLanguage language,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withAlpha(30),
          child: const Icon(Icons.person, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          _text(language, 'My Profile', 'Mbiri Yanga'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _text(
            language,
            'Manage your account settings',
            'Sinthani zokonda za akaunti yanu',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _text(AppLanguage language, String english, String chichewa) {
    return language == AppLanguage.chichewa ? chichewa : english;
  }

  String _formatToday(AppLanguage language) {
    final now = DateTime.now();
    if (language != AppLanguage.chichewa) {
      return DateFormat('EEEE, d MMMM yyyy').format(now);
    }

    const weekdays = [
      'Lolemba',
      'Lachiwiri',
      'Lachitatu',
      'Lachinayi',
      'Lachisanu',
      'Loweruka',
      'Lamlungu',
    ];
    const months = [
      'Januware',
      'Febuluwale',
      'Malichi',
      'Epulo',
      'Meyi',
      'Juni',
      'Julayi',
      'Ogasiti',
      'Seputembala',
      'Okutobala',
      'Novembala',
      'Disembala',
    ];

    return '${weekdays[now.weekday - 1]}, ${now.day} '
        '${months[now.month - 1]} ${now.year}';
  }
}
