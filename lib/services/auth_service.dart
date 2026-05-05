import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class AuthService {

  // Send OTP to phone
  static Future<void> sendOTP(String phone) async {
    await supabase.auth.signInWithOtp(
      phone: '+91$phone',
    );
  }

  // Verify OTP
  static Future<AuthResponse> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    final response = await supabase.auth.verifyOTP(
      phone: '+91$phone',
      token: otp,
      type: OtpType.sms,
    );
    return response;
  }

  // Get current user
  static User? get currentUser => supabase.auth.currentUser;

  // Get current user ID
  static String? get currentUserId => supabase.auth.currentUser?.id;

  // Get current user phone
  static String? get currentUserPhone => supabase.auth.currentUser?.phone;

  // Is logged in
  static bool get isLoggedIn => supabase.auth.currentSession != null;

  // Sign out
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Auth state stream
  static Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;
}