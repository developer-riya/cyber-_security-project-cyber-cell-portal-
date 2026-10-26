import 'dart:io';

import 'package:cyberuday/models/cyber_risk_signal.dart';
import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/models/threat_analysis.dart';
import 'package:cyberuday/services/document_intelligence.dart';
import 'package:cyberuday/services/quarantine_storage.dart';
import 'package:cyberuday/services/share_threat_analysis_service.dart';
import 'package:cyberuday/services/threat_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixtureDirectory;

  setUp(() async {
    fixtureDirectory = await Directory.systemTemp.createTemp(
      'cyber-uday-document-fixtures-',
    );
  });

  tearDown(() async {
    if (await fixtureDirectory.exists()) {
      await fixtureDirectory.delete(recursive: true);
    }
  });

  Future<File> writeFixture(String name, Object content) async {
    final File file = File('${fixtureDirectory.path}/$name');
    if (content is String) {
      await file.writeAsString(content);
    } else {
      await file.writeAsBytes(content as List<int>);
    }
    return file;
  }

  test('extracts bounded PDF structure, metadata, text, and URLs', () async {
    final File file = await writeFixture(
      'normal.pdf',
      _pdf(
        text: 'Hello from a harmless document.',
        url: 'https://example.com/help',
        metadata: true,
      ),
    );
    const LocalDocumentIntelligence analyzer = LocalDocumentIntelligence();

    final DocumentIntelligenceResult result = await analyzer.analyze(
      reference: file.uri.toString(),
      fileName: 'normal.pdf',
      mimeType: 'application/pdf',
    );

    expect(result.status, DocumentIntelligenceStatus.complete);
    expect(result.documentType, 'pdf');
    expect(result.metadata.title, 'Harmless fixture');
    expect(result.metadata.pageCount, 1);
    expect(result.extractedText, contains('Hello from a harmless document'));
    expect(result.extractedUrls, contains('https://example.com/help'));
    expect(result.evidence['PDF_PERFORMANCE'], isNotEmpty);
  });

  test('routes PDF text and URLs through existing analyzers', () async {
    final File file = await writeFixture(
      'suspicious.pdf',
      _pdf(
        text: 'URGENT verify your bank account OTP password immediately.',
        url: 'http://bit.ly/verify-account',
      ),
    );
    final ShareThreatAnalysis result = await const DocumentAnalyzer()
        .analyzeAsync(_payload(file, 'suspicious.pdf'), _quarantine(file));

    expect(result.risk, ShareThreatRisk.highRisk);
    expect(result.indicators, contains(contains('pressure')));
    expect(result.structuredEvidence, contains('PDF_URLS'));
    expect(result.structuredEvidence, contains('TEXT_ANALYSIS'));
    expect(result.message, isNot(contains('opened')));
  });

  test('active content is detected but never executed', () async {
    final File file = await writeFixture(
      'active.pdf',
      _pdf(
        text: 'Please review this document.',
        extra: '/JavaScript /OpenAction /EmbeddedFile /Launch',
      ),
    );
    final ShareThreatAnalysis result = await const DocumentAnalyzer()
        .analyzeAsync(_payload(file, 'active.pdf'), _quarantine(file));

    expect(result.risk, ShareThreatRisk.highRisk);
    expect(result.structuredEvidence['PDF_ACTIVE_CONTENT'], isNotEmpty);
    expect(result.structuredEvidence['PDF_EMBEDDED_CONTENT'], isNotEmpty);
    expect(
      result.structuredEvidence['PDF_ACTIVE_CONTENT']!.join(' '),
      contains('nothing was executed'),
    );
  });

  test('malformed and encrypted PDFs remain unknown', () async {
    final File malformed = await writeFixture('broken.pdf', const <int>[
      37,
      80,
      68,
      70,
      45,
    ]);
    final File encrypted = await writeFixture(
      'locked.pdf',
      _pdf(text: '', extra: '/Encrypt', includeTextObject: false),
    );
    const LocalDocumentIntelligence analyzer = LocalDocumentIntelligence();

    final DocumentIntelligenceResult malformedResult = await analyzer.analyze(
      reference: malformed.uri.toString(),
      fileName: 'broken.pdf',
      mimeType: 'application/pdf',
    );
    final ShareThreatAnalysis encryptedResult = await const DocumentAnalyzer()
        .analyzeAsync(
          _payload(encrypted, 'locked.pdf'),
          _quarantine(encrypted),
        );

    expect(malformedResult.status, DocumentIntelligenceStatus.unknown);
    expect(encryptedResult.status, ShareAnalysisStatus.analysisUnavailable);
  });

  test('partial encrypted PDFs preserve threat evidence without a safe verdict', () async {
    final File file = await writeFixture(
      'locked-active.pdf',
      _pdf(
        text: '',
        extra: '/Encrypt /JavaScript',
        includeTextObject: false,
      ),
    );

    final ShareThreatAnalysis result = await const DocumentAnalyzer()
        .analyzeAsync(
          _payload(file, 'locked-active.pdf'),
          _quarantine(file),
        );

    expect(result.status, ShareAnalysisStatus.partial);
    expect(result.risk, ShareThreatRisk.suspicious);
    expect(result.indicators, contains(contains('JAVASCRIPT_INDICATOR')));
  });

  test('plain text documents are supported', () async {
    final File text = await writeFixture(
      'notice.txt',
      'This is a plain text notice. No action is required.',
    );
    const LocalDocumentIntelligence analyzer = LocalDocumentIntelligence();

    final DocumentIntelligenceResult result = await analyzer.analyze(
      reference: text.uri.toString(),
      fileName: 'notice.txt',
      mimeType: 'text/plain',
    );

    expect(result.status, DocumentIntelligenceStatus.complete);
    expect(result.documentType, 'text-document');
    expect(result.extractedText, contains('plain text notice'));
  });

  test('risk signals preserve neutral UNKNOWN semantics', () {
    final ThreatAnalysisResult unknown = ThreatAnalysisResult(
      requestId: 'unknown',
      status: ThreatResultStatus.analysisUnavailable,
      verdict: ThreatVerdict.unknown,
      riskScore: 0,
      confidence: 0,
      detectedThreats: <String>[],
      evidence: <String>['Parser failure'],
      recommendedActions: <String>['Keep the item closed.'],
      analyzedAt: DateTime(2026),
      analyzerResults: <String>['PDF'],
      durationMs: 2,
      features: ThreatFeatures(
        suspiciousDomain: false,
        phishingIndicator: false,
        suspiciousUrl: false,
        impersonationIndicator: false,
        urgencyIndicator: false,
        credentialTheftIndicator: false,
        suspiciousFileType: false,
        knownThreat: false,
        unknownRisk: true,
      ),
    );
    final CyberRiskSignal signal = CyberRiskSignal.fromResult(unknown);

    expect(signal.level, CyberRiskLevel.unknown);
    expect(signal.label, 'UNKNOWN');
    expect(signal.colorToken, CyberRiskColorToken.neutralGray);
    expect(signal.score, 0);
  });

  test('fusion reaches CRITICAL only with combined strong signals', () {
    final ThreatAnalysisRequest request = ThreatAnalysisRequest(
      requestId: 'critical-fixture',
      inputType: IncomingShareContentType.pdf,
      mimeType: 'application/pdf',
      fileNames: <String>['active.pdf'],
      totalSizeBytes: 100,
      references: <String>[],
      extractedText: null,
      url: null,
      sourceApplication: 'fixture',
      receivedAt: DateTime(2026),
      metadata: <String, Object?>{},
    );
    const ThreatFeatures features = ThreatFeatures(
      suspiciousDomain: true,
      phishingIndicator: true,
      suspiciousUrl: true,
      impersonationIndicator: true,
      urgencyIndicator: true,
      credentialTheftIndicator: true,
      suspiciousFileType: false,
      knownThreat: false,
      unknownRisk: false,
      activeContentIndicator: true,
      embeddedFileIndicator: true,
      launchActionIndicator: true,
      javascriptIndicator: true,
    );
    final ThreatAnalysisResult result = const ThreatFusionEngine().fuse(
      request: request,
      analysis: const ShareThreatAnalysis(
        risk: ShareThreatRisk.highRisk,
        status: ShareAnalysisStatus.highRisk,
        title: 'Fixture',
        message: 'Fixture',
        indicators: <String>['combined indicators'],
        recommendations: <String>['Keep closed'],
        analyzerName: 'Fixture',
      ),
      features: features,
      durationMs: 1,
    );

    expect(result.verdict, ThreatVerdict.critical);
    expect(result.riskScore, 100);
  });
}

IncomingSharePayload _payload(File file, String name) =>
    IncomingSharePayload.fromManualFiles(<IncomingShareAttachment>[
      IncomingShareAttachment.fromFileReference(
        reference: file.uri.toString(),
        fileName: name,
        sizeBytes: file.lengthSync(),
        mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'text/plain',
      ),
    ]);

QuarantineRecord _quarantine(File file) => QuarantineRecord(
  requestId: 'fixture',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026, 1, 1, 0, 1),
  metadata: const <String, Object?>{},
  contents: <QuarantinedContent>[
    QuarantinedContent(
      attachmentIndex: 0,
      reference: file.uri.toString(),
      sizeBytes: file.lengthSync(),
    ),
  ],
);

String _pdf({
  required String text,
  String? url,
  bool metadata = false,
  String extra = '',
  bool includeTextObject = true,
}) {
  final String content = includeTextObject
      ? 'BT (${text.replaceAll(')', r'\)')}${url == null ? '' : ' $url'}) Tj ET'
      : '';
  final String info = metadata
      ? '5 0 obj << /Title (Harmless fixture) /Author (Cyber Uday Test) /Creator (Fixture) /Producer (Fixture) >> endobj'
      : '';
  return '''%PDF-1.7
1 0 obj << /Type /Catalog /Pages 2 0 R $extra >> endobj
2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /Contents 4 0 R >> endobj
4 0 obj << /Length ${content.length} >> stream
$content
endstream endobj
$info
trailer << /Root 1 0 R >>
%%EOF
''';
}
