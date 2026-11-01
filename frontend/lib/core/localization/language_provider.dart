import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'campusos_preferred_language';
  static final LanguageProvider instance = LanguageProvider._internal();

  factory LanguageProvider() => instance;

  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;
  Locale get currentLocale => Locale(_currentLanguage);
  String get currentLanguageName => supportedLanguages[_currentLanguage] ?? 'English';

  String getText(String key) => AppStrings.tr(key, lang: _currentLanguage);
  String tr(String key) => AppStrings.tr(key, lang: _currentLanguage);

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'or': 'ଓଡ଼ିଆ',
    'bn': 'বাংলা',
  };

  LanguageProvider._internal() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && supportedLanguages.containsKey(saved)) {
        _currentLanguage = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) return;
    if (_currentLanguage == languageCode) return;

    _currentLanguage = languageCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, languageCode);
    } catch (_) {}
  }
}

/// Fallback-safe consumer widget that reactivity listens to LanguageProvider across the entire app
class SafeLanguageConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, String currentLanguage, String languageName) builder;

  const SafeLanguageConsumer({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) {
        final code = LanguageProvider.instance.currentLanguage;
        final name = LanguageProvider.supportedLanguages[code] ?? 'English';
        return builder(context, code, name);
      },
    );
  }
}
