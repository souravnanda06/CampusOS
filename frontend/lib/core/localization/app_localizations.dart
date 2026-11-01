import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'app_strings.dart';
import 'language_provider.dart';

extension LocalizationExtension on BuildContext {
  String tr(String keyOrText) {
    try {
      final lang = watch<LanguageProvider>().currentLanguage;
      return AppStrings.tr(keyOrText, lang: lang);
    } catch (_) {
      return AppStrings.tr(keyOrText, lang: LanguageProvider.instance.currentLanguage);
    }
  }

  String trRead(String keyOrText) {
    try {
      final lang = read<LanguageProvider>().currentLanguage;
      return AppStrings.tr(keyOrText, lang: lang);
    } catch (_) {
      return AppStrings.tr(keyOrText, lang: LanguageProvider.instance.currentLanguage);
    }
  }
}

extension StringTranslationExtension on String {
  /// Translates this string to the currently active language.
  /// If [context] is provided, it will watch [LanguageProvider] so widgets rebuild reactively.
  String tr([BuildContext? context]) {
    if (context != null) {
      try {
        final lang = Provider.of<LanguageProvider>(context, listen: true).currentLanguage;
        return AppStrings.tr(this, lang: lang);
      } catch (_) {}
    }
    return LanguageProvider.instance.tr(this);
  }
}
