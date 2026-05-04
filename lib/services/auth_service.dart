import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth service using Supabase Auth (phone OTP).
class AuthService {
  static final _auth = Supabase.instance.client.auth;

  /// Send OTP to the given phone number.
  static Future<void> sendOTP(String phone) async {
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';
    await _auth.signInWithOtp(phone: fullPhone);
  }

  /// Verify the OTP code for the given phone number.
  static Future<AuthResponse> verifyOTP(String phone, String otp) async {
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';
    final response = await _auth.verifyOTP(
      phone: fullPhone,
      token: otp,
      type: OtpType.sms,
    );
    return response;
  }

  /// Get the currently logged-in user (or null).
  static User? get currentUser => _auth.currentUser;

  /// Check if user is logged in.
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Get the current session.
  static Session? get currentSession => _auth.currentSession;

  /// Sign out the current user.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Listen to auth state changes.
  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
}
