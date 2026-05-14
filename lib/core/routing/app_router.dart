import 'package:flutter/material.dart';
import 'package:smart_agri_price_tracker/features/splash/presentation/pages/splash_screen.dart';
import 'package:smart_agri_price_tracker/features/auth/presentation/pages/landing_page.dart';
import 'package:smart_agri_price_tracker/features/auth/presentation/pages/login_page.dart';
import 'package:smart_agri_price_tracker/features/auth/presentation/pages/register_page.dart';
import 'package:smart_agri_price_tracker/features/debug/presentation/pages/firestore_test_page.dart';
import 'package:smart_agri_price_tracker/features/farmer/presentation/pages/farmer_prices_page.dart';
import 'package:smart_agri_price_tracker/features/farmer/presentation/pages/search_prices_page.dart';
import 'package:smart_agri_price_tracker/features/farmer/presentation/pages/farmer_trends_page.dart';
import 'package:smart_agri_price_tracker/features/cooperative/presentation/pages/upload_price_page.dart';
import 'package:smart_agri_price_tracker/features/cooperative/presentation/pages/my_prices_page.dart';
import 'package:smart_agri_price_tracker/features/cooperative/presentation/pages/edit_price_page.dart';
import 'package:smart_agri_price_tracker/features/admin/presentation/pages/manage_users_page.dart';
import 'package:smart_agri_price_tracker/features/admin/presentation/pages/price_approval_page.dart';
import 'package:smart_agri_price_tracker/features/admin/presentation/pages/admin_analytics_page.dart';
import 'package:smart_agri_price_tracker/features/shared/presentation/pages/notifications_page.dart';
import 'package:smart_agri_price_tracker/features/shared/presentation/pages/profile_page.dart';
import 'package:smart_agri_price_tracker/core/services/auth_wrapper.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String landing = '/landing';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String firestoreTest = '/firestore-test';
  static const String marketPrices = '/market-prices';
  static const String searchPrices = '/search-prices';
  static const String priceTrends = '/price-trends';
  static const String uploadPrice = '/upload-price';
  static const String myPrices = '/my-prices';
  static const String editPrice = '/edit-price';
  static const String manageUsers = '/manage-users';
  static const String priceApproval = '/price-approval';
  static const String adminAnalytics = '/admin-analytics';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      landing: (context) => const LandingPage(),
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      home: (context) => const AuthWrapper(),
      firestoreTest: (context) => const FirestoreTestPage(),
      marketPrices: (context) => const FarmerPricesPage(),
      searchPrices: (context) => const SearchPricesPage(),
      priceTrends: (context) => const FarmerTrendsPage(),
      uploadPrice: (context) => const UploadPricePage(),
      myPrices: (context) => const MyPricesPage(),
      manageUsers: (context) => const ManageUsersPage(),
      priceApproval: (context) => const PriceApprovalPage(),
      adminAnalytics: (context) => const AdminAnalyticsPage(),
      notifications: (context) => const NotificationsPage(),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case landing:
        return MaterialPageRoute(builder: (_) => const LandingPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case home:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case firestoreTest:
        return MaterialPageRoute(builder: (_) => const FirestoreTestPage());
      case marketPrices:
        return MaterialPageRoute(builder: (_) => const FarmerPricesPage());
      case searchPrices:
        return MaterialPageRoute(builder: (_) => const SearchPricesPage());
      case priceTrends:
        return MaterialPageRoute(builder: (_) => const FarmerTrendsPage());
      case uploadPrice:
        return MaterialPageRoute(builder: (_) => const UploadPricePage());
      case myPrices:
        return MaterialPageRoute(builder: (_) => const MyPricesPage());
      case priceApproval:
        return MaterialPageRoute(builder: (_) => const PriceApprovalPage());
      case adminAnalytics:
        return MaterialPageRoute(builder: (_) => const AdminAnalyticsPage());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case manageUsers:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ManageUsersPage(initialRole: args?['role']),
        );
      case editPrice:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) =>
              EditPricePage(docId: args['docId'], initialData: args['data']),
        );
      case profile:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ProfilePage(userData: args),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
