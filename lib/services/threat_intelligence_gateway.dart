import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/threat_intelligence.dart';
import 'security_audit_logger.dart';
import 'security_pipeline_config.dart';
import 'threat_analysis_interfaces.dart';
import 'url_threat_analysis_service.dart';

DateTime _systemNow() => DateTime.now();

class NotConfiguredThreatIntelligenceProvider
    implements ThreatIntelligenceProvider {
  const NotConfiguredThreatIntelligenceProvider();

  @override
  String get providerName => 'not-configured';

  @override
  bool get isConfigured => false;

  @override
  Future<ThreatIntelligenceResult> lookup(
    ThreatIntelligenceLookupRequest request,
  ) async => ThreatIntelligenceResult(
    indicatorType: request.indicatorType,
    status: ThreatIntelligenceStatus.notConfigured,
    providerName: providerName,
    lookupDurationMs: 0,
    lookedUpAt: DateTime.now(),
    privacy: ThreatIntelligencePrivacyMetadata(
      providerConfigured: false,
      indicatorType: request.indicatorType,
      transmittedValueType: ThreatIntelligenceTransmittedValueType.none,
      privacyMode: ThreatIntelligencePrivacyMode.noExternalTransmission,
    ),
  );
}

class ThreatIntelligenceRateLimitContext {
  const ThreatIntelligenceRateLimitContext({
    required this.requestId,
    required this.providerName,
    required this.indicatorType,
    required this.indicatorFingerprint,
  });

  final String requestId;
  final String providerName;
  final ThreatIntelligenceIndicatorType indicatorType;
  final String indicatorFingerprint;
}

abstract interface class ThreatIntelligenceRateLimiter {
  Future<bool> allow(ThreatIntelligenceRateLimitContext context);

  void record(ThreatIntelligenceRateLimitContext context);
}

class AllowAllThreatIntelligenceRateLimiter
    implements ThreatIntelligenceRateLimiter {
  const AllowAllThreatIntelligenceRateLimiter();

  @override
  Future<bool> allow(ThreatIntelligenceRateLimitContext context) async => true;

  @override
  void record(ThreatIntelligenceRateLimitContext context) {}
}

class FixedWindowThreatIntelligenceRateLimiter
    implements ThreatIntelligenceRateLimiter {
  FixedWindowThreatIntelligenceRateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? clock,
  }) : clock = clock ?? _systemNow {
    if (maxRequests <= 0) {
      throw ArgumentError.value(
        maxRequests,
        'maxRequests',
        'Must be positive.',
      );
    }
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'Must be positive.');
    }
  }

  final int maxRequests;
  final Duration window;
  final DateTime Function() clock;
  final Queue<DateTime> _reservations = Queue<DateTime>();

  @override
  Future<bool> allow(ThreatIntelligenceRateLimitContext context) async {
    final DateTime now = clock();
    final DateTime cutoff = now.subtract(window);
    while (_reservations.isNotEmpty && !_reservations.first.isAfter(cutoff)) {
      _reservations.removeFirst();
    }
    if (_reservations.length >= maxRequests) return false;
    _reservations.addLast(now);
    return true;
  }

  @override
  void record(ThreatIntelligenceRateLimitContext context) {}
}

abstract interface class ThreatIntelligenceCache {
  ThreatIntelligenceResult? get(String key, DateTime now);

  void put(String key, ThreatIntelligenceResult result, DateTime now);

  int get length;
}

class BoundedThreatIntelligenceCache implements ThreatIntelligenceCache {
  BoundedThreatIntelligenceCache({
    required this.maxEntries,
    required this.ttl,
  }) {
    if (maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive.');
    }
    if (ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be positive.');
    }
  }

  final int maxEntries;
  final Duration ttl;
  final LinkedHashMap<String, _ThreatIntelligenceCacheEntry> _entries =
      LinkedHashMap<String, _ThreatIntelligenceCacheEntry>();

  @override
  int get length => _entries.length;

  @override
  ThreatIntelligenceResult? get(String key, DateTime now) {
    _removeExpired(now);
    final _ThreatIntelligenceCacheEntry? entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.result;
  }

  @override
  void put(String key, ThreatIntelligenceResult result, DateTime now) {
    _removeExpired(now);
    _entries.remove(key);
    _entries[key] = _ThreatIntelligenceCacheEntry(
      result: result,
      expiresAt: now.add(ttl),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void _removeExpired(DateTime now) {
    _entries.removeWhere(
      (String _, _ThreatIntelligenceCacheEntry entry) =>
          !entry.expiresAt.isAfter(now),
    );
  }
}

class _ThreatIntelligenceCacheEntry {
  const _ThreatIntelligenceCacheEntry({
    required this.result,
    required this.expiresAt,
  });

  final ThreatIntelligenceResult result;
  final DateTime expiresAt;
}

/// Provider-neutral reputation boundary. This class normalizes indicators but
/// never fetches a submitted URL, resolves DNS, opens a browser, or sends file
/// bytes and paths to a provider.
class ThreatIntelligenceGateway {
  ThreatIntelligenceGateway({
    this.provider = const NotConfiguredThreatIntelligenceProvider(),
    this.rateLimiter = const AllowAllThreatIntelligenceRateLimiter(),
    this.auditLogger = const NoOpSecurityAuditLogger(),
    this.config = const SecurityPipelineConfig(),
    this.urlNormalizer = const UrlNormalizationService(),
    ThreatIntelligenceCache? cache,
    this.clock = _systemNow,
  }) : cache =
           cache ??
           BoundedThreatIntelligenceCache(
             maxEntries: config.maxThreatIntelligenceCacheEntries,
             ttl: config.threatIntelligenceCacheTtl,
           ) {
    if (config.threatIntelligenceTimeout <= Duration.zero) {
      throw ArgumentError.value(
        config.threatIntelligenceTimeout,
        'threatIntelligenceTimeout',
        'Must be positive.',
      );
    }
    if (config.maxConcurrentThreatIntelligenceLookups <= 0) {
      throw ArgumentError.value(
        config.maxConcurrentThreatIntelligenceLookups,
        'maxConcurrentThreatIntelligenceLookups',
        'Must be positive.',
      );
    }
  }

  final ThreatIntelligenceProvider provider;
  final ThreatIntelligenceRateLimiter rateLimiter;
  final SecurityAuditLogger auditLogger;
  final SecurityPipelineConfig config;
  final UrlNormalizationService urlNormalizer;
  final ThreatIntelligenceCache cache;
  final DateTime Function() clock;
  final Map<String, Future<ThreatIntelligenceResult>> _inFlight =
      <String, Future<ThreatIntelligenceResult>>{};

  Future<ThreatIntelligenceResult> lookupUrl({
    required String requestId,
    required String url,
  }) {
    final UrlNormalizationResult normalized = urlNormalizer.normalize(url);
    return _lookup(
      requestId: requestId,
      type: ThreatIntelligenceIndicatorType.url,
      normalizedIndicator: normalized.url?.value,
      validationError: normalized.error,
    );
  }

  Future<ThreatIntelligenceResult> lookupHash({
    required String requestId,
    required String sha256Value,
  }) {
    final String normalized = sha256Value.trim().toLowerCase();
    return _lookup(
      requestId: requestId,
      type: ThreatIntelligenceIndicatorType.sha256,
      normalizedIndicator: RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)
          ? normalized
          : null,
      validationError: 'The SHA-256 indicator is malformed.',
    );
  }

  Future<ThreatIntelligenceResult> lookupDomain({
    required String requestId,
    required String domain,
  }) {
    final String normalized = domain.trim().toLowerCase();
    return _lookup(
      requestId: requestId,
      type: ThreatIntelligenceIndicatorType.domain,
      normalizedIndicator: _isValidDomain(normalized) ? normalized : null,
      validationError: 'The domain indicator is malformed.',
    );
  }

  Future<ThreatIntelligenceResult> lookupIp({
    required String requestId,
    required String ip,
  }) {
    final String? normalized = _normalizeIpAddress(ip);
    return _lookup(
      requestId: requestId,
      type: ThreatIntelligenceIndicatorType.ip,
      normalizedIndicator: normalized,
      validationError: 'The IP indicator is malformed.',
    );
  }

  Future<ThreatIntelligenceResult> _lookup({
    required String requestId,
    required ThreatIntelligenceIndicatorType type,
    required String? normalizedIndicator,
    required String? validationError,
  }) async {
    if (normalizedIndicator == null) {
      final ThreatIntelligenceResult result = _failureResult(
        type: type,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.validation,
        evidence: <String>[validationError ?? 'The indicator is invalid.'],
      );
      _record(
        SecurityAuditEventType.threatIntelligenceError,
        requestId,
        type,
        null,
        result.status,
      );
      return result;
    }

    final String fullFingerprint = _fingerprint(normalizedIndicator);
    final String auditFingerprint = fullFingerprint.substring(0, 16);
    final String cacheKey =
        '${provider.providerName}:${type.name}:$fullFingerprint';
    final DateTime now = clock();
    final ThreatIntelligenceResult? cached = cache.get(cacheKey, now);
    if (cached != null) {
      _record(
        SecurityAuditEventType.threatIntelligenceCacheHit,
        requestId,
        type,
        auditFingerprint,
        cached.status,
        cacheHit: true,
      );
      return cached.copyWith(
        lookupDurationMs: 0,
        lookedUpAt: now,
        fromCache: true,
      );
    }

    final Future<ThreatIntelligenceResult>? duplicate = _inFlight[cacheKey];
    if (duplicate != null) return duplicate;
    if (_inFlight.length >= config.maxConcurrentThreatIntelligenceLookups) {
      final ThreatIntelligenceResult result = _failureResult(
        type: type,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.rateLimited,
        evidence: const <String>[
          'The reputation lookup concurrency limit was reached; local analysis remains available.',
        ],
      );
      _record(
        SecurityAuditEventType.threatIntelligenceError,
        requestId,
        type,
        auditFingerprint,
        result.status,
      );
      return result;
    }

    final Future<ThreatIntelligenceResult> operation = _invokeProvider(
      requestId: requestId,
      type: type,
      normalizedIndicator: normalizedIndicator,
      fingerprint: auditFingerprint,
      cacheKey: cacheKey,
    );
    _inFlight[cacheKey] = operation;
    try {
      return await operation;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<ThreatIntelligenceResult> _invokeProvider({
    required String requestId,
    required ThreatIntelligenceIndicatorType type,
    required String normalizedIndicator,
    required String fingerprint,
    required String cacheKey,
  }) async {
    _record(
      SecurityAuditEventType.threatIntelligenceLookupStarted,
      requestId,
      type,
      fingerprint,
      null,
      cacheHit: false,
    );
    final ThreatIntelligenceRateLimitContext rateLimitContext =
        ThreatIntelligenceRateLimitContext(
          requestId: requestId,
          providerName: provider.providerName,
          indicatorType: type,
          indicatorFingerprint: fingerprint,
        );
    if (provider.isConfigured && !await rateLimiter.allow(rateLimitContext)) {
      final ThreatIntelligenceResult result = _failureResult(
        type: type,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.rateLimited,
        evidence: const <String>[
          'The reputation lookup was limited; local analysis remains available.',
        ],
      );
      _recordOutcome(requestId, fingerprint, result);
      return result;
    }
    if (provider.isConfigured) rateLimiter.record(rateLimitContext);

    final ThreatIntelligencePrivacyMetadata requestPrivacy =
        ThreatIntelligencePrivacyMetadata(
          providerConfigured: provider.isConfigured,
          indicatorType: type,
          transmittedValueType: provider.isConfigured
              ? _transmittedValueTypeFor(type)
              : ThreatIntelligenceTransmittedValueType.none,
          privacyMode: provider.isConfigured
              ? ThreatIntelligencePrivacyMode.indicatorOnly
              : ThreatIntelligencePrivacyMode.noExternalTransmission,
        );
    final ThreatIntelligenceLookupRequest request =
        ThreatIntelligenceLookupRequest(
          requestId: requestId,
          indicatorType: type,
          indicator: normalizedIndicator,
          privacy: requestPrivacy,
        );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final ThreatIntelligenceResult providerResult = await provider
          .lookup(request)
          .timeout(config.threatIntelligenceTimeout);
      stopwatch.stop();
      if (!_isValidProviderResult(providerResult, type)) {
        final ThreatIntelligenceResult result = _failureResult(
          type: type,
          status: ThreatIntelligenceStatus.error,
          errorCategory: ThreatIntelligenceErrorCategory.malformedResponse,
          evidence: const <String>[
            'The provider returned an invalid response; it was discarded.',
          ],
          durationMs: stopwatch.elapsedMilliseconds,
        );
        _recordOutcome(requestId, fingerprint, result);
        return result;
      }
      final ThreatIntelligenceResult result = providerResult.copyWith(
        lookupDurationMs: stopwatch.elapsedMilliseconds,
        lookedUpAt: clock(),
      );
      if (_isCacheable(result.status)) {
        cache.put(cacheKey, result, clock());
      }
      _recordOutcome(requestId, fingerprint, result);
      return result;
    } on TimeoutException {
      stopwatch.stop();
      final ThreatIntelligenceResult result = _failureResult(
        type: type,
        status: ThreatIntelligenceStatus.timeout,
        evidence: const <String>[
          'The reputation provider timed out; local analysis remains available.',
        ],
        durationMs: stopwatch.elapsedMilliseconds,
      );
      _recordOutcome(requestId, fingerprint, result);
      return result;
    } catch (_) {
      stopwatch.stop();
      final ThreatIntelligenceResult result = _failureResult(
        type: type,
        status: ThreatIntelligenceStatus.error,
        errorCategory: ThreatIntelligenceErrorCategory.provider,
        evidence: const <String>[
          'The reputation provider failed; local analysis remains available.',
        ],
        durationMs: stopwatch.elapsedMilliseconds,
      );
      _recordOutcome(requestId, fingerprint, result);
      return result;
    }
  }

  bool _isValidProviderResult(
    ThreatIntelligenceResult result,
    ThreatIntelligenceIndicatorType expectedType,
  ) {
    final double? confidence = result.confidence;
    final bool noTransmissionResult =
        result.status == ThreatIntelligenceStatus.unsupported;
    return result.indicatorType == expectedType &&
        result.providerName == provider.providerName &&
        result.providerName.trim().isNotEmpty &&
        (confidence == null ||
            (confidence.isFinite && confidence >= 0 && confidence <= 1)) &&
        !result.privacy.rawContentTransmitted &&
        !result.privacy.rawFileTransmitted &&
        result.privacy.indicatorType == expectedType &&
        result.privacy.providerConfigured == provider.isConfigured &&
        result.privacy.transmittedValueType ==
            (noTransmissionResult
                ? ThreatIntelligenceTransmittedValueType.none
                : provider.isConfigured
                ? _transmittedValueTypeFor(expectedType)
                : ThreatIntelligenceTransmittedValueType.none) &&
        result.privacy.privacyMode ==
            (noTransmissionResult
                ? ThreatIntelligencePrivacyMode.noExternalTransmission
                : provider.isConfigured
                ? ThreatIntelligencePrivacyMode.indicatorOnly
                : ThreatIntelligencePrivacyMode.noExternalTransmission);
  }

  ThreatIntelligenceResult _failureResult({
    required ThreatIntelligenceIndicatorType type,
    required ThreatIntelligenceStatus status,
    required List<String> evidence,
    ThreatIntelligenceErrorCategory? errorCategory,
    int durationMs = 0,
  }) => ThreatIntelligenceResult(
    indicatorType: type,
    status: status,
    providerName: provider.providerName,
    matchedEvidence: List<String>.unmodifiable(evidence),
    lookupDurationMs: durationMs,
    lookedUpAt: clock(),
    privacy: ThreatIntelligencePrivacyMetadata(
      providerConfigured: provider.isConfigured,
      indicatorType: type,
      transmittedValueType: provider.isConfigured
          ? _transmittedValueTypeFor(type)
          : ThreatIntelligenceTransmittedValueType.none,
      privacyMode: provider.isConfigured
          ? ThreatIntelligencePrivacyMode.indicatorOnly
          : ThreatIntelligencePrivacyMode.noExternalTransmission,
    ),
    errorCategory: errorCategory,
  );

  void _recordOutcome(
    String requestId,
    String fingerprint,
    ThreatIntelligenceResult result,
  ) {
    final SecurityAuditEventType eventType = switch (result.status) {
      ThreatIntelligenceStatus.notConfigured =>
        SecurityAuditEventType.threatIntelligenceNotConfigured,
      ThreatIntelligenceStatus.timeout =>
        SecurityAuditEventType.threatIntelligenceTimeout,
      ThreatIntelligenceStatus.error =>
        SecurityAuditEventType.threatIntelligenceError,
      _ => SecurityAuditEventType.threatIntelligenceLookupCompleted,
    };
    _record(
      eventType,
      requestId,
      result.indicatorType,
      fingerprint,
      result.status,
      durationMs: result.lookupDurationMs,
      cacheHit: false,
    );
  }

  void _record(
    SecurityAuditEventType eventType,
    String requestId,
    ThreatIntelligenceIndicatorType type,
    String? fingerprint,
    ThreatIntelligenceStatus? status, {
    int? durationMs,
    bool? cacheHit,
  }) {
    auditLogger.record(
      SecurityAuditEvent(
        type: eventType,
        requestId: requestId,
        createdAt: clock(),
        metadata: <String, Object?>{
          'provider': provider.providerName,
          'indicatorType': type.name,
          'operation': type.name,
          'privacyMode': provider.isConfigured
              ? ThreatIntelligencePrivacyMode.indicatorOnly.name
              : ThreatIntelligencePrivacyMode.noExternalTransmission.name,
          'indicatorFingerprint': ?fingerprint,
          'status': ?status?.name,
          'durationMs': ?durationMs,
          'cacheHit': ?cacheHit,
        },
      ),
    );
  }

  static bool _isCacheable(ThreatIntelligenceStatus status) => switch (status) {
    ThreatIntelligenceStatus.malicious ||
    ThreatIntelligenceStatus.suspicious ||
    ThreatIntelligenceStatus.clean ||
    ThreatIntelligenceStatus.unknown => true,
    ThreatIntelligenceStatus.unsupported ||
    ThreatIntelligenceStatus.notConfigured ||
    ThreatIntelligenceStatus.error ||
    ThreatIntelligenceStatus.timeout => false,
  };

  static String _fingerprint(String indicator) =>
      sha256.convert(utf8.encode(indicator)).toString();
}

ThreatIntelligenceTransmittedValueType _transmittedValueTypeFor(
  ThreatIntelligenceIndicatorType type,
) => switch (type) {
  ThreatIntelligenceIndicatorType.url =>
    ThreatIntelligenceTransmittedValueType.normalizedUrl,
  ThreatIntelligenceIndicatorType.sha256 =>
    ThreatIntelligenceTransmittedValueType.sha256,
  ThreatIntelligenceIndicatorType.domain =>
    ThreatIntelligenceTransmittedValueType.domain,
  ThreatIntelligenceIndicatorType.ip =>
    ThreatIntelligenceTransmittedValueType.ip,
};

bool _isValidDomain(String domain) {
  if (domain.isEmpty || domain.length > 253 || !domain.contains('.')) {
    return false;
  }
  if (domain.endsWith('.') || domain.contains(RegExp(r'[:/?#@\s]'))) {
    return false;
  }
  final List<String> labels = domain.split('.');
  return labels.every(
    (String label) =>
        label.isNotEmpty &&
        label.length <= 63 &&
        !label.startsWith('-') &&
        !label.endsWith('-') &&
        RegExp(r'^[a-z0-9-]+$').hasMatch(label),
  );
}

String? _normalizeIpAddress(String rawValue) {
  String value = rawValue.trim().toLowerCase();
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }
  final String? ipv4 = _normalizeIpv4(value);
  if (ipv4 != null) return ipv4;
  return _normalizeIpv6(value);
}

String? _normalizeIpv4(String value) {
  final List<String> parts = value.split('.');
  if (parts.length != 4) return null;
  final List<int> octets = <int>[];
  for (final String part in parts) {
    if (part.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(part)) return null;
    final int? octet = int.tryParse(part);
    if (octet == null || octet > 255) return null;
    octets.add(octet);
  }
  return octets.join('.');
}

String? _normalizeIpv6(String value) {
  if (!value.contains(':') || value.contains('%')) return null;
  if (!RegExp(r'^[0-9a-f:.]+$').hasMatch(value)) return null;
  final List<String> compressedParts = value.split('::');
  if (compressedParts.length > 2) return null;

  List<int>? parseSide(String side) {
    if (side.isEmpty) return <int>[];
    final List<String> groups = side.split(':');
    final List<int> values = <int>[];
    for (int index = 0; index < groups.length; index += 1) {
      final String group = groups[index];
      if (group.contains('.')) {
        if (index != groups.length - 1) return null;
        final String? ipv4 = _normalizeIpv4(group);
        if (ipv4 == null) return null;
        final List<int> octets = ipv4
            .split('.')
            .map(int.parse)
            .toList(growable: false);
        values
          ..add((octets[0] << 8) | octets[1])
          ..add((octets[2] << 8) | octets[3]);
        continue;
      }
      if (group.isEmpty ||
          group.length > 4 ||
          !RegExp(r'^[0-9a-f]{1,4}$').hasMatch(group)) {
        return null;
      }
      values.add(int.parse(group, radix: 16));
    }
    return values;
  }

  final List<int>? left = parseSide(compressedParts.first);
  final List<int>? right = compressedParts.length == 2
      ? parseSide(compressedParts.last)
      : <int>[];
  if (left == null || right == null) return null;
  final bool compressed = compressedParts.length == 2;
  final int suppliedGroups = left.length + right.length;
  if ((!compressed && suppliedGroups != 8) ||
      (compressed && suppliedGroups >= 8)) {
    return null;
  }
  final List<int> groups = <int>[
    ...left,
    if (compressed) ...List<int>.filled(8 - suppliedGroups, 0),
    ...right,
  ];
  return groups.map((int group) => group.toRadixString(16)).join(':');
}
