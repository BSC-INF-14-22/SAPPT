import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/notification_service.dart';
import 'package:smart_agri_price_tracker/features/shared/presentation/widgets/market_insights_card.dart';

class FarmerDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const FarmerDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final name = userData['fullName'] ?? 'Farmer';
    final district = userData['district'] ?? 'Not Set';
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRouter.home);
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
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
                      'Welcome, $name',
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
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRouter.profile,
                    arguments: userData,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withAlpha(30),
                    backgroundImage: userData['photoUrl'] != null
                        ? NetworkImage(userData['photoUrl'])
                        : null,
                    child: userData['photoUrl'] == null
                        ? Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
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
            const MarketInsightsCard(),
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
                  'View Prices',
                  Icons.monetization_on_outlined,
                  Colors.green,
                  () => Navigator.pushNamed(context, AppRouter.marketPrices),
                ),
                _buildDashboardCard(
                  context,
                  'Search Crops',
                  Icons.search_rounded,
                  Colors.blue,
                  () => Navigator.pushNamed(context, AppRouter.searchPrices),
                ),
                _buildDashboardCard(
                  context,
                  'Price Trends',
                  Icons.trending_up_rounded,
                  Colors.orange,
                  () => Navigator.pushNamed(context, AppRouter.priceTrends),
                ),
                StreamBuilder<int>(
                  stream: NotificationService().getUnreadCountStream(),
                  initialData: 0,
                  builder: (context, snapshot) {
                    return _buildDashboardCard(
                      context,
                      'Notifications',
                      Icons.notifications_active_outlined,
                      Colors.red,
                      () =>
                          Navigator.pushNamed(context, AppRouter.notifications),
                      notificationCount: snapshot.data ?? 0,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large Profile Card
            _buildProfileCard(
              context,
              theme,
              userData, // Pass userData here
              () => Navigator.pushNamed(
                context,
                AppRouter.profile,
                arguments: userData,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF2E7D32)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: Color(0xFF2E7D32)),
            label: 'Markets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF2E7D32)),
            label: 'Profile',
          ),
        ],
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppRouter.marketPrices);
          } else if (index == 2) {
            Navigator.pushNamed(
              context,
              AppRouter.profile,
              arguments: userData,
            );
          }
        },
      ),
    );
  }
}

Widget _buildDashboardCard(
  BuildContext context,
  String title,
  IconData icon,
  Color color,
  VoidCallback onTap, {
  int notificationCount = 0,
}) {
  return Card(
    elevation: 2,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
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
            if (notificationCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  child: Center(
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
  Map<String, dynamic> userData,
  VoidCallback onTap,
) {
  return Card(
    elevation: 2,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: theme.primaryColor.withAlpha(30),
        backgroundImage: userData['photoUrl'] != null
            ? NetworkImage(userData['photoUrl'])
            : null,
        child: userData['photoUrl'] == null
            ? const Icon(Icons.person, color: Color(0xFF2E7D32))
            : null,
      ),
      title: const Text(
        'My Profile',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Manage your account settings'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
