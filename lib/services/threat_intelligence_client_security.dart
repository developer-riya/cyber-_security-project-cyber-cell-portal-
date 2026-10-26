import 'auth_service.dart';
import 'app_check_service.dart';

class ThreatIntelligenceRequestSecurityHeaders {
  const ThreatIntelligenceRequestSecurityHeaders({
    this.authorization,
    this.appCheckToken,
  });

  final String? authorization;
  final String? appCheckToken;

  Map<String, String> toHttpHeaders() => <String, String>{
    'authorization': ?authorization,
    'x-firebase-appcheck': ?appCheckToken,
  };
}

abstract interface class ThreatIntelligenceRequestSecurityProvider {
  Future<ThreatIntelligenceRequestSecurityHeaders> headers();
}

class NoThreatIntelligenceRequestSecurityProvider
    implements ThreatIntelligenceRequestSecurityProvider {
  const NoThreatIntelligenceRequestSecurityProvider();

  @override
  Future<ThreatIntelligenceRequestSecurityHeaders> headers() async =>
      const ThreatIntelligenceRequestSecurityHeaders();
}

class FirebaseThreatIntelligenceRequestSecurityProvider
    implements ThreatIntelligenceRequestSecurityProvider {
  const FirebaseThreatIntelligenceRequestSecurityProvider();

  @override
  Future<ThreatIntelligenceRequestSecurityHeaders> headers() async {
    final String? idToken = await AuthService.instance.currentUser
        ?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return const ThreatIntelligenceRequestSecurityHeaders();
    }
    final String? appCheckToken = await AppCheckService.instance.token();
    return ThreatIntelligenceRequestSecurityHeaders(
      authorization: 'Bearer $idToken',
      appCheckToken: appCheckToken == null || appCheckToken.isEmpty
          ? null
          : appCheckToken,
    );
  }
}
