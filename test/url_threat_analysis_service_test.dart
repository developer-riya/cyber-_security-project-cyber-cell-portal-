import 'package:cyberuday/services/url_threat_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const UrlThreatAnalysisService service = UrlThreatAnalysisService();

  setUpAll(() {
    PublicSuffixDomainParser.initializeForTesting('''
com
org
net
uk
co.uk
io
dev
''');
  });

  test(
    'parses HTTPS and registrable domains with Public Suffix List rules',
    () {
      final UrlThreatAnalysis result = service.analyze(
        'https://portal.example.co.uk/sign-in?next=home#top',
      );

      expect(result.normalization.isValid, isTrue);
      expect(result.normalization.url!.uri.scheme, 'https');
      expect(result.domain!.hostname, 'portal.example.co.uk');
      expect(result.domain!.registrableDomain, 'example.co.uk');
      expect(result.domain!.subdomain, 'portal');
      expect(result.indicators, isEmpty);
    },
  );

  test('records HTTP without escalating a single weak signal to high risk', () {
    final UrlThreatAnalysis result = service.analyze('http://example.com');

    expect(result.indicators.single, contains('HTTP'));
    expect(result.signalCount, 1);
  });

  test('identifies IPv4, IPv6, localhost, and unusual ports safely', () {
    expect(
      service.analyze('https://192.0.2.1:8443/login').indicators.join(' '),
      allOf(contains('IP address'), contains('unusual port')),
    );
    expect(
      service.analyze('https://[2001:db8::1]/').domain!.isIpAddress,
      isTrue,
    );
    expect(
      service.analyze('http://localhost:8080/').domain!.isLocalhost,
      isTrue,
    );
  });

  test('extracts deterministic hostname and encoding indicators', () {
    final UrlThreatAnalysis result = service.analyze(
      'http://xn--paypa1-4ve.example.com/a%2Fb?next=%252Flogin',
    );

    expect(result.indicators.join(' '), contains('punycode'));
    expect(result.indicators.join(' '), contains('encoded'));
    expect(result.localEvidence['REPUTATION_RESULT'], isNotEmpty);
    expect(result.localEvidence['REDIRECT_RESULT'], isNotEmpty);
  });

  test('reports Unicode hostnames as evidence, not a verdict', () {
    final UrlThreatAnalysis result = service.analyze(
      'https://paypаl.example.com',
    );

    expect(result.indicators.join(' '), contains('Unicode'));
  });

  test(
    'identifies URL user-info, shortening, and credential-like patterns',
    () {
      final UrlThreatAnalysis atResult = service.analyze(
        'https://trusted.example@bit.ly/reset?otp=1234',
        surroundingText: 'Urgent account verification',
      );

      final String indicators = atResult.indicators.join(' ');
      expect(indicators, contains('@'));
      expect(indicators, contains('URL shortener'));
      expect(indicators, contains('credential'));
      expect(indicators, contains('account/security'));
    },
  );

  test('identifies excessive subdomains and excessive URL length', () {
    final String longPath = List<String>.filled(2100, 'a').join();
    final UrlThreatAnalysis result = service.analyze(
      'https://a.b.c.d.e.example.com/$longPath',
    );

    expect(result.indicators.join(' '), contains('deep subdomain'));
    expect(result.indicators.join(' '), contains('unusually long'));
  });

  test('rejects malformed or unsupported links without opening them', () {
    final UrlThreatAnalysis malformed = service.analyze('not a url');
    final UrlThreatAnalysis unsupported = service.analyze(
      'ftp://example.com/a',
    );

    expect(malformed.normalization.isValid, isFalse);
    expect(unsupported.normalization.isValid, isFalse);
  });

  test('same input produces the same local indicators', () {
    const String input = 'http://bit.ly/verify?password=please';
    expect(
      service.analyze(input).indicators,
      service.analyze(input).indicators,
    );
  });
}
