import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/supported_language.dart';
import 'localization_service.dart';

class LanguagePreferenceService {
  LanguagePreferenceService({SharedPreferences? preferences})
    : _preferences = preferences;

  static final LanguagePreferenceService instance = LanguagePreferenceService();

  static const String preferenceKey = 'cyber_uday.preferred_language';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<SupportedLanguage?> load() async {
    final String? code = (await _store).getString(preferenceKey);
    final SupportedLanguage? language = SupportedLanguage.fromCode(code);
    if (language != null) {
      LocalizationService.instance.setLocale(language.code);
    }
    return language;
  }

  Future<void> save(SupportedLanguage language) async {
    await (await _store).setString(preferenceKey, language.code);
    LocalizationService.instance.setLocale(language.code);
  }
}
