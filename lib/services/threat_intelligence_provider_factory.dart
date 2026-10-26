import 'security_audit_logger.dart';
import 'security_pipeline_config.dart';
import 'threat_analysis_interfaces.dart';
import 'threat_intelligence_gateway.dart';
import 'threat_intelligence_http_transport.dart';
import 'threat_intelligence_client_security.dart';
import 'virus_total_threat_intelligence_provider.dart';

/// Application-level provider composition. The only build-time values read by
/// Flutter are a non-secret enable flag and the Cyber Uday proxy URL.
class ThreatIntelligenceProviderFactory {
  ThreatIntelligenceProviderFactory._();

  static final VirusTotalProxyConfiguration _configuration =
      VirusTotalProxyConfiguration.fromEnvironment();
  static final ThreatIntelligenceProvider _provider =
      VirusTotalProxyThreatIntelligenceProvider(
        configuration: _configuration,
        transport: BoundedThreatIntelligenceHttpTransport(),
        requestSecurityProvider:
            const FirebaseThreatIntelligenceRequestSecurityProvider(),
      );
  static final SecurityPipelineConfig _defaultConfig =
      const SecurityPipelineConfig();
  static final ThreatIntelligenceCache _sharedCache =
      BoundedThreatIntelligenceCache(
        maxEntries: _defaultConfig.maxThreatIntelligenceCacheEntries,
        ttl: _defaultConfig.threatIntelligenceCacheTtl,
      );
  static final ThreatIntelligenceRateLimiter _sessionRateLimiter =
      FixedWindowThreatIntelligenceRateLimiter(
        maxRequests: 30,
        window: const Duration(minutes: 1),
      );

  static ThreatIntelligenceGateway createGateway({
    required SecurityAuditLogger auditLogger,
    required SecurityPipelineConfig config,
  }) => ThreatIntelligenceGateway(
    provider: _provider,
    rateLimiter: _sessionRateLimiter,
    auditLogger: auditLogger,
    config: config,
    cache: _sharedCache,
  );
}
