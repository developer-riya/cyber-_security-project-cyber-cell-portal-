import 'package:flutter/services.dart';
import 'package:public_suffix/public_suffix.dart';

/// A normalized, non-network representation of a submitted HTTP(S) URL.
class NormalizedUrl {
  const NormalizedUrl({
    required this.original,
    required this.value,
    required this.uri,
    required this.schemeWasInferred,
  });

  final String original;
  final String value;
  final Uri uri;
  final bool schemeWasInferred;
}

class UrlNormalizationResult {
  const UrlNormalizationResult._({this.url, this.error});

  const UrlNormalizationResult.valid(NormalizedUrl url) : this._(url: url);

  const UrlNormalizationResult.invalid(String error) : this._(error: error);

  final NormalizedUrl? url;
  final String? error;

  bool get isValid => url != null;
}

/// Parses URLs without opening them or initiating a network request.
class UrlNormalizationService {
  const UrlNormalizationService();

  UrlNormalizationResult normalize(String rawValue) {
    final String candidate = rawValue.trim();
    if (candidate.isEmpty || candidate.contains(RegExp(r'\s'))) {
      return const UrlNormalizationResult.invalid(
        'The link is empty or contains invalid whitespace.',
      );
    }

    final bool hasScheme = RegExp(
      r'^[a-zA-Z][a-zA-Z0-9+.-]*://',
    ).hasMatch(candidate);
    final String withScheme = hasScheme ? candidate : 'https://$candidate';
    final Uri? uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return const UrlNormalizationResult.invalid(
        'The link could not be parsed as a web address.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const UrlNormalizationResult.invalid(
        'Only HTTP and HTTPS links can be checked.',
      );
    }
    if (uri.host.contains(' ') || uri.host.endsWith('.')) {
      return const UrlNormalizationResult.invalid(
        'The link hostname is malformed.',
      );
    }
    return UrlNormalizationResult.valid(
      NormalizedUrl(
        original: rawValue,
        value: uri.toString(),
        uri: uri,
        schemeWasInferred: !hasScheme,
      ),
    );
  }
}

class UrlDomainParts {
  const UrlDomainParts({
    required this.hostname,
    this.registrableDomain,
    this.subdomain,
    this.publicSuffix,
    this.isIpAddress = false,
    this.isLocalhost = false,
    this.parsingAvailable = false,
  });

  final String hostname;
  final String? registrableDomain;
  final String? subdomain;
  final String? publicSuffix;
  final bool isIpAddress;
  final bool isLocalhost;
  final bool parsingAvailable;
}

/// Public Suffix List backed parsing. The rule snapshot is bundled so URL
/// analysis has no runtime network dependency. Refresh the asset deliberately
/// as part of dependency maintenance rather than fetching it from user input.
class PublicSuffixDomainParser {
  const PublicSuffixDomainParser();

  static SuffixRules? _rules;

  static Future<void> initialize() async {
    if (_rules != null) return;
    final String list = await rootBundle.loadString(
      'assets/public_suffix_list.dat',
    );
    _rules = SuffixRules.fromString(list);
  }

  static void initializeForTesting(String rules) {
    _rules = SuffixRules.fromString(rules);
  }

  UrlDomainParts parse(String hostname) {
    final String host = hostname.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) {
      return UrlDomainParts(hostname: host, isLocalhost: true);
    }
    if (_isIpAddress(host)) {
      return UrlDomainParts(hostname: host, isIpAddress: true);
    }
    final SuffixRules? rules = _rules;
    if (rules == null) return UrlDomainParts(hostname: host);
    try {
      final PublicSuffix parsed = PublicSuffix(
        urlString: 'https://$host',
        suffixRules: rules,
      );
      return UrlDomainParts(
        hostname: host,
        registrableDomain: parsed.icannDomain,
        subdomain: parsed.icannSubdomain,
        publicSuffix: parsed.icannSuffix,
        parsingAvailable: true,
      );
    } on FormatException {
      return UrlDomainParts(hostname: host, parsingAvailable: true);
    }
  }
}

enum RedirectAnalysisStatus { unavailable }

enum ThreatIntelligenceLookupStatus { notConfigured, available, unavailable }

class UrlThreatAnalysis {
  const UrlThreatAnalysis({
    required this.normalization,
    required this.domain,
    required this.localEvidence,
    required this.phishingIndicators,
    required this.redirectStatus,
    required this.threatIntelligenceStatus,
  });

  final UrlNormalizationResult normalization;
  final UrlDomainParts? domain;
  final Map<String, List<String>> localEvidence;
  final List<String> phishingIndicators;
  final RedirectAnalysisStatus redirectStatus;
  final ThreatIntelligenceLookupStatus threatIntelligenceStatus;

  /// Only local warning categories affect local risk. Availability notices for
  /// reputation and redirects stay in the structured result, but are not risk
  /// signals in their own right.
  List<String> get indicators => <String>[
    ...?localEvidence['URL_FEATURES'],
    ...?localEvidence['DOMAIN_FEATURES'],
    ...phishingIndicators,
  ];

  int get signalCount => indicators.length;
}

/// Deterministic local URL feature extraction. It does not open submitted
/// links, resolve DNS, download content, execute JavaScript, or follow redirects.
class UrlThreatAnalysisService {
  const UrlThreatAnalysisService({
    this.normalizer = const UrlNormalizationService(),
    this.domainParser = const PublicSuffixDomainParser(),
  });

  static const Set<String> _shorteners = <String>{
    'bit.ly',
    'tinyurl.com',
    't.co',
    'cutt.ly',
    'is.gd',
    'rb.gy',
    'shorturl.at',
  };

  static const Set<String> _suspiciousTerms = <String>{
    'verify',
    'verification',
    'secure',
    'security',
    'account',
    'update',
    'wallet',
    'bank',
    'payment',
    'invoice',
    'gift',
    'reward',
  };

  static const Set<String> _credentialTerms = <String>{
    'password',
    'passcode',
    'otp',
    'pin',
    'cvv',
    'card',
    'credential',
    'username',
  };

  final UrlNormalizationService normalizer;
  final PublicSuffixDomainParser domainParser;

  UrlThreatAnalysis analyze(String rawUrl, {String? surroundingText}) {
    final UrlNormalizationResult normalization = normalizer.normalize(rawUrl);
    if (!normalization.isValid) {
      return UrlThreatAnalysis(
        normalization: normalization,
        domain: null,
        localEvidence: <String, List<String>>{
          'URL_FEATURES': <String>[normalization.error!],
        },
        phishingIndicators: const <String>[],
        redirectStatus: RedirectAnalysisStatus.unavailable,
        threatIntelligenceStatus: ThreatIntelligenceLookupStatus.notConfigured,
      );
    }

    final NormalizedUrl normalized = normalization.url!;
    final Uri uri = normalized.uri;
    final UrlDomainParts domain = domainParser.parse(uri.host);
    final Map<String, List<String>> evidence = <String, List<String>>{
      'URL_FEATURES': <String>[],
      'DOMAIN_FEATURES': <String>[],
      'PHISHING_INDICATORS': <String>[],
      'REPUTATION_RESULT': const <String>[
        'Reputation is evaluated separately by the Threat Intelligence Gateway.',
      ],
      'REDIRECT_RESULT': const <String>[
        'Redirect analysis is unavailable; Cyber Uday did not open or follow this link.',
      ],
    };
    final List<String> urlFeatures = evidence['URL_FEATURES']!;
    final List<String> domainFeatures = evidence['DOMAIN_FEATURES']!;
    final List<String> phishing = evidence['PHISHING_INDICATORS']!;

    if (normalized.schemeWasInferred) {
      urlFeatures.add(
        'No scheme was supplied; HTTPS was assumed only for parsing.',
      );
    }
    if (uri.scheme == 'http') {
      urlFeatures.add('The link uses HTTP instead of encrypted HTTPS.');
    }
    if (uri.hasPort && !_isExpectedPort(uri)) {
      urlFeatures.add('The link uses unusual port ${uri.port}.');
    }
    if (normalized.value.length > 2048) {
      urlFeatures.add('The link is unusually long.');
    }
    if (RegExp(r'%(?:[0-9a-fA-F]{2})').hasMatch(rawUrl)) {
      urlFeatures.add('The submitted link contains encoded characters.');
    }
    if (rawUrl.toLowerCase().contains('%25')) {
      urlFeatures.add('The submitted link contains double-encoded characters.');
    }
    if (uri.userInfo.isNotEmpty || _hasAtBeforeAuthorityEnd(rawUrl)) {
      urlFeatures.add(
        'The link contains an @ or user-info component that can obscure its destination.',
      );
    }
    if (_shorteners.contains(uri.host.toLowerCase())) {
      urlFeatures.add(
        'The link uses a URL shortener that hides its destination.',
      );
    }

    if (domain.isLocalhost) {
      domainFeatures.add(
        'The link targets localhost and is not a public web destination.',
      );
    }
    if (domain.isIpAddress) {
      domainFeatures.add('The link points directly to an IP address.');
    }
    final List<String> labels = uri.host
        .split('.')
        .where((label) => label.isNotEmpty)
        .toList();
    if (!domain.isIpAddress && labels.length >= 5) {
      domainFeatures.add(
        'The hostname contains an unusually deep subdomain structure.',
      );
    }
    if (!domain.isIpAddress &&
        labels.any((label) => label.startsWith('xn--'))) {
      domainFeatures.add(
        'The hostname uses punycode (internationalized domain encoding).',
      );
    }
    if (_containsUnicode(_rawHostname(rawUrl))) {
      domainFeatures.add(
        'The hostname contains Unicode characters that may require closer inspection.',
      );
    }
    if (!domain.isIpAddress &&
        labels.any(
          (label) => label.length > 50 || label.split('-').length > 5,
        )) {
      domainFeatures.add('The hostname has an unusually structured label.');
    }

    final String combined = '${uri.path} ${uri.query} ${surroundingText ?? ''}'
        .toLowerCase();
    final Set<String> suspiciousMatches = _suspiciousTerms
        .where(combined.contains)
        .toSet();
    if (suspiciousMatches.isNotEmpty) {
      phishing.add(
        'The link or accompanying text contains account/security-themed terms: ${suspiciousMatches.join(', ')}.',
      );
    }
    final Set<String> credentialMatches = _credentialTerms
        .where(combined.contains)
        .toSet();
    if (credentialMatches.isNotEmpty) {
      phishing.add(
        'The link or accompanying text references credential-like data: ${credentialMatches.join(', ')}.',
      );
    }
    if (uri.queryParameters.keys.any(_credentialTerms.contains)) {
      phishing.add('The query contains a credential-related parameter name.');
    }

    return UrlThreatAnalysis(
      normalization: normalization,
      domain: domain,
      localEvidence: Map<String, List<String>>.unmodifiable(
        evidence.map(
          (key, value) => MapEntry<String, List<String>>(
            key,
            List<String>.unmodifiable(value),
          ),
        ),
      ),
      phishingIndicators: List<String>.unmodifiable(phishing),
      redirectStatus: RedirectAnalysisStatus.unavailable,
      threatIntelligenceStatus: ThreatIntelligenceLookupStatus.notConfigured,
    );
  }

  static bool _isExpectedPort(Uri uri) =>
      (uri.scheme == 'https' && uri.port == 443) ||
      (uri.scheme == 'http' && uri.port == 80);

  static bool _hasAtBeforeAuthorityEnd(String input) {
    final int authorityStart = input.indexOf('://');
    final int start = authorityStart == -1 ? 0 : authorityStart + 3;
    final int end = input.indexOf('/', start);
    return input.substring(start, end == -1 ? input.length : end).contains('@');
  }

  static bool _containsUnicode(String value) =>
      value.runes.any((rune) => rune > 0x7f);
}

bool _isIpAddress(String host) {
  if (host.contains(':')) return RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(host);
  final List<String> parts = host.split('.');
  return parts.length == 4 &&
      parts.every((part) {
        final int? value = int.tryParse(part);
        return value != null && value >= 0 && value <= 255;
      });
}

String _rawHostname(String input) {
  final int schemeEnd = input.indexOf('://');
  String authority = input.substring(schemeEnd == -1 ? 0 : schemeEnd + 3);
  final int pathStart = authority.indexOf(RegExp(r'[/?#]'));
  if (pathStart != -1) authority = authority.substring(0, pathStart);
  final int at = authority.lastIndexOf('@');
  if (at != -1) authority = authority.substring(at + 1);
  if (authority.startsWith('[')) {
    final int closingBracket = authority.indexOf(']');
    return closingBracket == -1
        ? authority
        : authority.substring(1, closingBracket);
  }
  final int port = authority.lastIndexOf(':');
  return port == -1 ? authority : authority.substring(0, port);
}
