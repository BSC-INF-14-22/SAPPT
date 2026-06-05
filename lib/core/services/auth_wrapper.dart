import 'package:flutter/material.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/features/auth/presentation/pages/landing_page.dart';
import 'package:smart_agri_price_tracker/features/farmer/presentation/pages/farmer_dashboard.dart';
import 'package:smart_agri_price_tracker/features/cooperative/presentation/pages/cooperative_dashboard.dart';
import 'package:smart_agri_price_tracker/features/admin/presentation/pages/admin_dashboard.dart';
import 'package:smart_agri_price_tracker/features/auth/domain/validators.dart';

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

        if (!user.emailVerified && !isTestAdminEmail(user.email)) {
          return _buildEmailVerificationScreen(context, user.email);
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

              if (userData['isDisabled'] == true) {
                return _buildErrorScreen(
                  context,
                  'Your account has been disabled. Contact an administrator.',
                  showLogout: true,
                );
              }

              if (role == 'Cooperative Officer' &&
                  userData['approved'] != true) {
                return _buildErrorScreen(
                  context,
                  'Your cooperative account is pending admin approval.',
                  showLogout: true,
                );
              }

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

  Widget _buildEmailVerificationScreen(BuildContext context, String? email) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: Color(0xFF2E7D32),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to ${email ?? 'your email address'}. Check your inbox and spam folder, open the link, then come back and refresh.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await AuthService().reloadCurrentUser();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed(AppRouter.home);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('I Verified My Email'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await AuthService().sendEmailVerification();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent.')),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not send verification email. Check your internet connection and try again.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.outgoing_mail),
                label: const Text('Resend Email'),
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
