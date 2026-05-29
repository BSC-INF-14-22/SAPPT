import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';

class CooperativeDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const CooperativeDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final name = userData['fullName'] ?? 'Officer';
    final district = userData['district'] ?? 'Not Set';

    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperative Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRouter.landing);
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
                        const Icon(Icons.badge, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Cooperative Officer - $district',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showProfileDialog(context, name, userData),
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
            const SizedBox(height: 32),

            // Grid of Action Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cardSize = (constraints.maxWidth - 16) / 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: cardSize,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return _buildDashboardCard(
                          context,
                          'Upload Prices',
                          Icons.cloud_upload_outlined,
                          Colors.green,
                          () => Navigator.pushNamed(
                            context,
                            AppRouter.uploadPrice,
                          ),
                        );
                      case 1:
                        return _buildDashboardCard(
                          context,
                          'My Prices',
                          Icons.list_alt_rounded,
                          Colors.blue,
                          () =>
                              Navigator.pushNamed(context, AppRouter.myPrices),
                        );
                      case 2:
                        return _buildDashboardCard(
                          context,
                          'Edit Prices',
                          Icons.edit_note_rounded,
                          Colors.orange,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select a price from "My Prices" to edit it.',
                                ),
                              ),
                            );
                            Navigator.pushNamed(context, AppRouter.myPrices);
                          },
                        );
                      default:
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: uid != null
                              ? FirebaseFirestore.instance
                                    .collection('notifications')
                                    .where('uid', isEqualTo: uid)
                                    .where('readStatus', isEqualTo: false)
                                    .snapshots()
                              : const Stream.empty(),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data?.docs.length ?? 0;
                            return _buildDashboardCard(
                              context,
                              'Notifications',
                              Icons.notifications_active_outlined,
                              Colors.red,
                              () => _openNotifications(context),
                              badgeCount: unreadCount,
                            );
                          },
                        );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF2E7D32)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF2E7D32)),
            label: 'Activity',
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
            Navigator.pushNamed(context, AppRouter.myPrices);
          } else if (index == 2) {
            _showProfileDialog(context, name, userData);
          }
        },
      ),
    );
  }

  void _showProfileDialog(
    BuildContext context,
    String name,
    Map<String, dynamic> userData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Officer Profile'),
        content: Text(
          'Name: $name\nRole: Cooperative Officer\nDistrict: ${userData['district'] ?? 'Not Set'}\nEmail: ${userData['email'] ?? 'N/A'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Stack(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: double.infinity,
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
        ),
        if (badgeCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .where('readStatus', isEqualTo: false)
          .get();
      for (final doc in querySnapshot.docs) {
        await FirestoreService().updateData('notifications', doc.id, {
          'readStatus': true,
        });
      }
    }
    if (context.mounted) {
      Navigator.pushNamed(context, AppRouter.notifications);
    }
  }
}
