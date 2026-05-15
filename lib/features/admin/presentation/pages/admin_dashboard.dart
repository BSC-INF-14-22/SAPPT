import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/notification_service.dart';

class AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const AdminDashboard({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final name = userData['fullName'] ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Admin Profile'),
                        content: Text('Name: $name\nRole: Administrator\nEmail: ${userData['email'] ?? 'N/A'}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.primaryColor.withAlpha(30),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.primaryColor, 
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $name',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'System Administrator',
                      style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            Text(
              'System Overview',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Total Users',
                  'users',
                  null,
                  null,
                  Icons.people_alt_rounded,
                  Colors.blue,
                  onTap: () => Navigator.pushNamed(context, AppRouter.manageUsers),
                ),
                _buildStatCard(
                  'Farmers',
                  'users',
                  'role',
                  'Farmer',
                  Icons.agriculture_rounded,
                  Colors.green,
                  onTap: () => Navigator.pushNamed(context, AppRouter.manageUsers, arguments: {'role': 'Farmer'}),
                ),
                _buildStatCard(
                  'Cooperatives',
                  'users',
                  'role',
                  'Cooperative Officer',
                  Icons.business_center_rounded,
                  Colors.orange,
                  onTap: () => Navigator.pushNamed(context, AppRouter.manageUsers, arguments: {'role': 'Cooperative Officer'}),
                ),
                _buildStatCard(
                  'Pending Prices',
                  'prices',
                  'status',
                  'pending',
                  Icons.hourglass_empty_rounded,
                  Colors.amber,
                  onTap: () => Navigator.pushNamed(context, AppRouter.priceApproval),
                ),
                _buildStatCard(
                  'Approved Prices',
                  'prices',
                  'status',
                  'approved',
                  Icons.verified_rounded,
                  Colors.teal,
                  onTap: () => Navigator.pushNamed(context, AppRouter.marketPrices),
                ),
                _buildStatCard(
                  'Analytics',
                  'products', 
                  null,
                  null,
                  Icons.analytics_rounded,
                  Colors.indigo,
                  onTap: () => Navigator.pushNamed(context, AppRouter.adminAnalytics),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            _buildQuickActions(context, theme),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF2E7D32)),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppRouter.manageUsers);
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon in next update.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label, 
    String? collection, 
    String? field, 
    dynamic value, 
    IconData icon, 
    Color color, 
    {String? valueOverride, VoidCallback? onTap}
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: collection != null 
          ? (field != null 
              ? FirebaseFirestore.instance.collection(collection).where(field, isEqualTo: value).snapshots()
              : FirebaseFirestore.instance.collection(collection).snapshots())
          : null,
      builder: (context, snapshot) {
        String displayValue = '...';
        if (valueOverride != null) {
          displayValue = valueOverride;
        } else if (snapshot.hasData) {
          displayValue = snapshot.data!.docs.length.toString();
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 24),
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline, color: Colors.green),
            title: const Text('Review Pending Prices'),
            subtitle: const Text('Verify submissions from market officers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRouter.priceApproval),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_add_outlined, color: Colors.blue),
            title: const Text('User Management'),
            subtitle: const Text('Approve or suspend accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, AppRouter.manageUsers),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined, color: Colors.orange),
            title: const Text('Send Announcement'),
            subtitle: const Text('Broadcast market alerts to all users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAnnouncementDialog(context),
          ),
        ),
      ],
    );
  }

  void _showAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title (e.g., Market Alert)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending broadcast...')));
              
              // We need to import NotificationService in the actual file. 
              // We'll use the static instance.
              try {
                await NotificationService().sendGlobalBroadcast(
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast sent to all users!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );
  }
}
