import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations appLocalizationsFor(String localeCode) {
  final bool supported = AppLocalizations.supportedLocales.any(
    (Locale locale) => locale.languageCode == localeCode,
  );
  return lookupAppLocalizations(
    supported ? Locale(localeCode) : const Locale('en'),
  );
}
