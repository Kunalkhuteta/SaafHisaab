import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:saafhisaab/firebase_options.dart';
import 'package:saafhisaab/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/set_passcode_screen.dart';
import 'screens/auth/passcode_screen.dart';
import 'screens/auth/shop_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'globalVar.dart';

// Global navigator key for lifecycle observer
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['PROJECT_URL']!,
    anonKey: dotenv.env['ANON_PUBLIC_KEY']!,
  );

  final connected = await SupabaseService.testConnection();
  print(connected ? '✅ Supabase connected' : '❌ Supabase failed');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notification init error: $e');
  }

  runApp(const ProviderScope(child: SaafHisaabApp()));
}

// Global Supabase client
final supabase = Supabase.instance.client;

class SaafHisaabApp extends ConsumerStatefulWidget {
  const SaafHisaabApp({super.key});
  @override
  ConsumerState<SaafHisaabApp> createState() => _SaafHisaabAppState();
}

class _SaafHisaabAppState extends ConsumerState<SaafHisaabApp>
    with WidgetsBindingObserver {
  bool _isShowingPasscode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — save timestamp
      SessionService.saveLastActiveTime();
    } else if (state == AppLifecycleState.resumed) {
      // App coming back — check if we need passcode
      _checkPasscodeOnResume();
    }
  }

  Future<void> _checkPasscodeOnResume() async {
    if (_isShowingPasscode) return;
    final session = supabase.auth.currentSession;
    if (session == null) return;

    final shouldShow = await SessionService.shouldShowPasscode();
    if (shouldShow && navigatorKey.currentState != null) {
      _isShowingPasscode = true;
      final result = await navigatorKey.currentState!.push<bool>(
        MaterialPageRoute(builder: (_) => const PasscodeScreen()),
      );
      _isShowingPasscode = false;
      if (result == true) {
        await SessionService.saveLastActiveTime();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SaafHisaab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// Smart routing with passcode checks
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('SaafHisaab...',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }

        final session = supabase.auth.currentSession;
        if (session == null) return const LoginScreen();

        // Session exists — check passcode
        return FutureBuilder<List<bool>>(
          future: Future.wait([
            SessionService.isPasscodeSet(),
            SessionService.shouldShowPasscode(),
            SupabaseService.shopExists(session.user.id),
          ]),
          builder: (context, futureSnap) {
            if (!futureSnap.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            final isPasscodeSet = futureSnap.data![0];
            final shouldShowPasscode = futureSnap.data![1];
            final shopExists = futureSnap.data![2];

            // No shop yet → shop setup (passcode comes after)
            if (!shopExists) return const ShopSetupScreen();

            // No passcode set → set one
            if (!isPasscodeSet) return const SetPasscodeScreen();

            // Passcode set + should show → ask for it
            if (shouldShowPasscode) return const _PasscodeGate();

            // All good → home
            return const HomeScreen();
          },
        );
      },
    );
  }
}

// Intermediate widget that shows PasscodeScreen and navigates to Home on success
class _PasscodeGate extends StatefulWidget {
  const _PasscodeGate();
  @override
  State<_PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends State<_PasscodeGate> {
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPasscode());
  }

  Future<void> _showPasscode() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PasscodeScreen()),
    );
    if (result == true && mounted) {
      setState(() => _verified = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return const HomeScreen();
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}