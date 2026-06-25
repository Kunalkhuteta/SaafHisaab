import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saafhisaab/utils/indian_date_time.dart';
import 'auth_service.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static String get _passcodeKey {
    final userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return 'saafhisaab_passcode';
    }
    return 'saafhisaab_passcode_$userId';
  }

  static String get _lastActiveKey {
    final userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return 'saafhisaab_last_active';
    }
    return 'saafhisaab_last_active_$userId';
  }

  static String get _timeoutKey {
    final userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return 'session_timeout_minutes';
    }
    return 'session_timeout_minutes_$userId';
  }

  static String get _attemptsKey {
    final userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return 'saafhisaab_passcode_attempts';
    }
    return 'saafhisaab_passcode_attempts_$userId';
  }

  static String get _lockedUntilKey {
    final userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      return 'saafhisaab_passcode_locked_until';
    }
    return 'saafhisaab_passcode_locked_until_$userId';
  }

  // ── Hash passcode with SHA-256 ──
  static String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    return sha256.convert(bytes).toString();
  }

  // ── Save passcode (hashed) ──
  static Future<void> savePasscode(String passcode) async {
    final hashed = _hashPasscode(passcode);
    await _storage.write(key: _passcodeKey, value: hashed);
  }

  // ── Verify passcode ──
  static Future<bool> verifyPasscode(String input) async {
    final stored = await _storage.read(key: _passcodeKey);
    if (stored == null) return false;
    return _hashPasscode(input) == stored;
  }

  // ── Clear passcode ──
  static Future<void> clearPasscode() async {
    await _storage.delete(key: _passcodeKey);
    await _storage.delete(key: _lastActiveKey);
    await _storage.delete(key: _attemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  // ── Check if passcode is set ──
  static Future<bool> isPasscodeSet() async {
    final stored = await _storage.read(key: _passcodeKey);
    return stored != null && stored.isNotEmpty;
  }

  // ── Get passcode attempts ──
  static Future<int> getPasscodeAttempts() async {
    final val = await _storage.read(key: _attemptsKey);
    return int.tryParse(val ?? '') ?? 0;
  }

  // ── Save passcode attempts ──
  static Future<void> savePasscodeAttempts(int attempts) async {
    await _storage.write(key: _attemptsKey, value: attempts.toString());
  }

  // ── Clear passcode attempts ──
  static Future<void> clearPasscodeAttempts() async {
    await _storage.delete(key: _attemptsKey);
  }

  // ── Get passcode locked until ──
  static Future<DateTime?> getPasscodeLockedUntil() async {
    final val = await _storage.read(key: _lockedUntilKey);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  // ── Save passcode locked until ──
  static Future<void> savePasscodeLockedUntil(DateTime? dateTime) async {
    if (dateTime == null) {
      await _storage.delete(key: _lockedUntilKey);
    } else {
      await _storage.write(key: _lockedUntilKey, value: dateTime.toIso8601String());
    }
  }

  // ── Save last active time ──
  static Future<void> saveLastActiveTime() async {
    await _storage.write(
      key: _lastActiveKey,
      value: IndianDateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // ── Check if passcode screen should show ──
  static Future<bool> shouldShowPasscode() async {
    final hasPasscode = await isPasscodeSet();
    if (!hasPasscode) return false;

    final timeoutMinutes = await getTimeoutSetting();

    // -1 = Never
    if (timeoutMinutes == -1) return false;

    // 0 = Immediately (every time)
    if (timeoutMinutes == 0) return true;

    // Check elapsed time
    final lastActiveStr = await _storage.read(key: _lastActiveKey);
    if (lastActiveStr == null) return true; // No last active = show passcode

    final lastActive = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(lastActiveStr) ?? 0,
    );
    final elapsed = IndianDateTime.now().difference(lastActive);
    return elapsed.inMinutes >= timeoutMinutes;
  }

  // ── Get timeout setting (minutes) ──
  static Future<int> getTimeoutSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timeoutKey) ?? 5; // Default: 5 minutes
  }

  // ── Save timeout setting ──
  static Future<void> saveTimeoutSetting(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeoutKey, minutes);
  }
}
