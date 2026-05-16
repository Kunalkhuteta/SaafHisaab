import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;

class AppLanguageNotifier extends Notifier<bool> {
  @override
  bool build() {
    return prefs.getBool('appLanguageEn') ?? true;
  }

  void setLanguage(bool isEn) {
    state = isEn;
    prefs.setBool('appLanguageEn', isEn);
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, bool>(AppLanguageNotifier.new);

class AppLang {
  static String tr(bool isEn, String en, String hi) {
    return isEn ? en : hi;
  }
}

class ChartTypeNotifier extends Notifier<String> {
  @override
  String build() {
    return prefs.getString('defaultChartType') ?? 'bar';
  }

  void setChartType(String type) {
    state = type;
    prefs.setString('defaultChartType', type);
  }
}

final chartTypeProvider = NotifierProvider<ChartTypeNotifier, String>(ChartTypeNotifier.new);
