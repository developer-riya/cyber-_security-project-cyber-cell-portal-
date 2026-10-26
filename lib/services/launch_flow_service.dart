import '../core/localization/supported_language.dart';
import 'language_preference_service.dart';

enum LaunchDestination { languageSelection, existingFlow }

class LaunchFlowService {
  LaunchFlowService({LanguagePreferenceService? preferences})
    : _preferences = preferences ?? LanguagePreferenceService.instance;

  static final LaunchFlowService instance = LaunchFlowService();

  final LanguagePreferenceService _preferences;

  Future<LaunchDestination> resolve() async {
    final SupportedLanguage? language = await _preferences.load();
    return language == null
        ? LaunchDestination.languageSelection
        : LaunchDestination.existingFlow;
  }
}
