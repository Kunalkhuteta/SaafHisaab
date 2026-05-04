import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file FIRST — without this, all env vars are empty!
  await dotenv.load(fileName: '.env');

  final projectUrl = dotenv.env['PROJECT_URL'] ?? '';
  final anonKey = dotenv.env['ANON_PUBLIC_KEY'] ?? '';

  if (projectUrl.isEmpty || anonKey.isEmpty) {
    print('❌ ERROR: Supabase credentials missing from .env file!');
    print('   PROJECT_URL: ${projectUrl.isEmpty ? "MISSING" : "OK"}');
    print('   ANON_PUBLIC_KEY: ${anonKey.isEmpty ? "MISSING" : "OK"}');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: projectUrl,
    anonKey: anonKey,
  );

  runApp(const ProviderScope(child: SaafHisaabApp()));
}

// Global supabase client — use this anywhere in the app
final supabase = Supabase.instance.client;

class SaafHisaabApp extends ConsumerWidget {
  const SaafHisaabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
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
      // For now goes to login — Day 4 we add smart routing
      home: const LoginScreen(),
    );
  }
}