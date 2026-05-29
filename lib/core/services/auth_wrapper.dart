import 'package:flutter/material.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/features/auth/presentation/pages/landing_page.dart';
import 'package:smart_agri_price_tracker/features/farmer/presentation/pages/farmer_dashboard.dart';
import 'package:smart_agri_price_tracker/features/cooperative/presentation/pages/cooperative_dashboard.dart';
import 'package:smart_agri_price_tracker/features/admin/presentation/pages/admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // If snapshot has error, show error screen
        if (snapshot.hasError) {
          return _buildErrorScreen(context, 'Auth Error: ${snapshot.error}');
        }

        final user = snapshot.data;

        // If not logged in, go straight to Landing Page
        if (user == null) {
          // If connection is still waiting, we might show a splash but Landing is safer to prevent black screen
          return const LandingPage();
        }

        // If logged in, fetch role
        return FutureBuilder<Map<String, dynamic>?>(
          future: FirestoreService().getUserByUid(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen(context, 'Fetching your profile...');
            }

            if (roleSnapshot.hasError) {
              return _buildErrorScreen(
                context,
                'Database Error: ${roleSnapshot.error}',
              );
            }

            if (roleSnapshot.hasData && roleSnapshot.data != null) {
              final userData = roleSnapshot.data!;
              final role = userData['role'];

              switch (role) {
                case 'Farmer':
                  return FarmerDashboard(userData: userData);
                case 'Cooperative Officer':
                  return CooperativeDashboard(userData: userData);
                case 'Admin':
                  return AdminDashboard(userData: userData);
                default:
                  return FarmerDashboard(userData: userData);
              }
            }

            // User authenticated but no profile found
            return _buildErrorScreen(
              context,
              'Profile not found. Please try logging out and registering again.',
              showLogout: true,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    BuildContext context,
    String message, {
    bool showLogout = true,
  }) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (showLogout)
                ElevatedButton(
                  onPressed: () => _signOutToLanding(context),
                  child: const Text('Logout & Try Again'),
                ),
              TextButton(
                onPressed: () => _signOutToLanding(context),
                child: const Text('Back to Landing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOutToLanding(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.landing);
    }
  }
}
