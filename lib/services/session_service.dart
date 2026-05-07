import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();
  static const _passcodeKey = 'saafhisaab_passcode';
  static const _lastActiveKey = 'saafhisaab_last_active';
  static const _timeoutKey = 'session_timeout_minutes';

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
  }

  // ── Check if passcode is set ──
  static Future<bool> isPasscodeSet() async {
    final stored = await _storage.read(key: _passcodeKey);
    return stored != null && stored.isNotEmpty;
  }

  // ── Save last active time ──
  static Future<void> saveLastActiveTime() async {
    await _storage.write(
      key: _lastActiveKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
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
    final elapsed = DateTime.now().difference(lastActive);
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
