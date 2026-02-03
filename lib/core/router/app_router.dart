import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/admin/presentation/admin_home_page.dart';
import '../../features/driver/presentation/driver_home_page.dart';
import '../../features/client/presentation/client_home_page.dart';
import '../../features/auth/presentation/role_selection_page.dart';
import '../../features/driver/presentation/driver_signup_page.dart';
import '../../features/client/presentation/client_signup_page.dart';
import '../../features/admin/presentation/admin_pending_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/driver/presentation/pending_approval_page.dart';

// Simple placeholder pages for now
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomePage(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverHomePage(),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => const ClientHomePage(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionPage(),
      ),
      GoRoute(
        path: '/driver-signup',
        builder: (context, state) => const DriverSignupPage(),
      ),
      GoRoute(
        path: '/client-signup',
        builder: (context, state) => const ClientSignupPage(),
      ),
      GoRoute(
        path: '/admin-pending',
        builder: (context, state) => const AdminPendingPage(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalPage(),
      ),
    ],
  );
});
