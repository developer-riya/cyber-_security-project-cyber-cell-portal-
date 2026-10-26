import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'core/cyber_design_system.dart';
import 'l10n/app_localizations.dart';
import 'models/incoming_share_payload.dart';
import 'services/auth_service.dart';
import 'services/app_check_service.dart';
import 'screens/splash_screen.dart';
import 'screens/share_to_scan_screen.dart';
import 'services/incoming_share_service.dart';
import 'services/localization_service.dart';
import 'theme/app_theme.dart';
import 'core/cyber_branding.dart';
import 'services/browser_title.dart';
import 'services/url_threat_analysis_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PublicSuffixDomainParser.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppCheckService.instance.initialize();
  await AuthService.instance.initializePersistence();
  await IncomingShareService.instance.initialize();
  runApp(const CyberUApp());
}

class CyberUApp extends StatefulWidget {
  const CyberUApp({super.key});

  @override
  State<CyberUApp> createState() => _CyberUAppState();
}

class _CyberUAppState extends State<CyberUApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<IncomingSharePayload>? _liveShareSubscription;
  bool _isPresentingShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyCyberUdayBrowserTitle();
    });
    _liveShareSubscription = IncomingShareService.instance.liveShares.listen(
      _presentLiveShare,
    );
  }

  @override
  void dispose() {
    _liveShareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _presentLiveShare(IncomingSharePayload payload) async {
    if (_isPresentingShare) return;
    _isPresentingShare = true;
    try {
      await Future<void>.delayed(Duration.zero);
      final NavigatorState? navigator = _navigatorKey.currentState;
      if (navigator == null || !mounted) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ShareToScanScreen(payload: payload),
        ),
      );
    } finally {
      _isPresentingShare = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (context, localeCode, child) {
        final bool isSupported = AppLocalizations.supportedLocales.any(
          (locale) => locale.languageCode == localeCode,
        );
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: cyberUdayBrowserTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          locale: isSupported ? Locale(localeCode) : const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              CyberAmbientPointer(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        );
      },
    );
  }
}
