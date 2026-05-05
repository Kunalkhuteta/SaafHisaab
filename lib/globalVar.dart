import 'package:flutter_riverpod/flutter_riverpod.dart';

// true = English, false = Hindi
final appLanguageProvider = StateProvider<bool>((ref) => true);

class AppLang {
  static String tr(bool isEn, String en, String hi) {
    return isEn ? en : hi;
  }
}
