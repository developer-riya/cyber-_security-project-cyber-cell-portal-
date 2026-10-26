import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferenceService {
  OnboardingPreferenceService({SharedPreferences? preferences})
    : _preferences = preferences;

  static final OnboardingPreferenceService instance =
      OnboardingPreferenceService();

  static const String completionKey = 'cyber_uday.onboarding_complete';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<bool> isComplete() async =>
      (await _store).getBool(completionKey) ?? false;

  Future<void> markComplete() async {
    await (await _store).setBool(completionKey, true);
  }
}
