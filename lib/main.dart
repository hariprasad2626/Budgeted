import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'providers/accounting_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/add_donation_screen.dart';
import 'screens/add_transfer_screen.dart';
import 'screens/add_adjustment_screen.dart';
import 'screens/monthly_report_screen.dart';
import 'screens/category_manager_screen.dart';
import 'screens/budget_allocation_screen.dart';
import 'screens/fixed_amounts_manager_screen.dart';
import 'screens/cost_center_manager_screen.dart';
import 'screens/budget_period_manager_screen.dart';
import 'firebase_options.dart';
import 'screens/reports_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/personal_ledger_screen.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Offline Persistence for Web (Lightning Fast Open)
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firestore Persistence Error: $e");
  }
  
  // Sign in anonymously removed - now using Google Auth
  /*
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint("Auth failed: $e");
  }
  */

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Accounts',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal, 
              brightness: provider.isDarkMode ? Brightness.dark : Brightness.light
            ),
            useMaterial3: true,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          home: const AuthWrapper(),
          routes: {
            '/add-expense': (context) => const AddExpenseScreen(),
            '/add-donation': (context) => const AddDonationScreen(),
            '/add-transfer': (context) => const AddTransferScreen(),
            '/add-adjustment': (context) => const AddAdjustmentScreen(),
            '/manage-categories': (context) => const CategoryManagerScreen(),
            '/manage-allocations': (context) => const BudgetAllocationScreen(),
            '/monthly-report': (context) => const MonthlyBudgetReportScreen(),
            '/fixed-amounts': (context) => const FixedAmountsManagerScreen(),
            '/manage-cost-centers': (context) => const CostCenterManagerScreen(),
            '/manage-budget-periods': (context) => const BudgetPeriodManagerScreen(),
            '/reports': (context) => const ReportsScreen(),
            '/ledger': (context) => const LedgerScreen(),
            '/personal-ledger': (context) => const PersonalLedgerScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final user = snapshot.data;
        if (user != null) {
          // The isUserWhitelistedSync method is assumed to be part of AuthService.
          // The provided snippet's content for isUserWhitelisted and isUserWhitelistedSync
          // should be placed within the AuthService class definition in services/auth_service.dart.
          // The AuthWrapper already correctly calls AuthService().isUserWhitelistedSync(user).
          final isWhitelisted = AuthService().isUserWhitelistedSync(user);
          if (isWhitelisted) {
            return const DashboardScreen();
          } else {
            return const AccessDeniedScreen();
          }
        }
        return const LoginScreen();
      },
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your email is not on the approved whitelist. Please contact the administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
