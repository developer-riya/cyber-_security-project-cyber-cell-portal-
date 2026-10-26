import '../models/incoming_share_payload.dart';
import 'image_evidence_extractor.dart';
import 'image_evidence_models.dart';
import 'quarantine_storage.dart';
import 'url_threat_analysis_service.dart';
import 'document_intelligence.dart';
import 'apk_static_analysis.dart';
import 'archive_static_analysis.dart';

enum ShareThreatRisk { safe, suspicious, highRisk, unsupported, error }

enum ShareAnalysisStatus {
  safe,
  suspicious,
  highRisk,
  partial,
  analysisUnavailable,
  error,
}

class ShareThreatAnalysis {
  const ShareThreatAnalysis({
    required this.risk,
    required this.status,
    required this.title,
    required this.message,
    required this.indicators,
    required this.recommendations,
    required this.analyzerName,
    this.structuredEvidence = const <String, List<String>>{},
    this.threatIntelligenceConfigured = false,
  });

  final ShareThreatRisk risk;
  final ShareAnalysisStatus status;
  final String title;
  final String message;
  final List<String> indicators;
  final List<String> recommendations;
  final String analyzerName;
  final Map<String, List<String>> structuredEvidence;
  final bool threatIntelligenceConfigured;
}

abstract interface class ShareAnalyzer {
  String get name;

  bool canAnalyze(IncomingSharePayload payload);

  ShareThreatAnalysis analyze(IncomingSharePayload payload);
}

/// Routes normalized share inputs to small, replaceable analyzers.
///
/// Current file analyzers intentionally stop at safe classification and
/// metadata. Deep inspection belongs behind an isolated analysis gateway, not
/// inside the user's device process.
class ShareThreatAnalysisService {
  const ShareThreatAnalysisService({
    this.analyzers = _defaultAnalyzers,
    this.imageAnalyzer = const ImageThreatAnalyzer(),
    this.documentAnalyzer = const DocumentAnalyzer(),
    this.apkAnalyzer = const ApkAnalyzer(),
    this.archiveAnalyzer = const ArchiveAnalyzer(),
  });

  static const List<ShareAnalyzer> _defaultAnalyzers = <ShareAnalyzer>[
    UrlAnalyzer(),
    TextThreatAnalyzer(),
    ImageAnalyzer(),
    DocumentAnalyzer(),
    ApkAnalyzer(),
    ArchiveAnalyzer(),
    MediaAnalyzer(),
    UnsupportedAnalyzer(),
  ];

  final List<ShareAnalyzer> analyzers;
  final ImageThreatAnalyzer imageAnalyzer;
  final DocumentAnalyzer documentAnalyzer;
  final ApkAnalyzer apkAnalyzer;
  final ArchiveAnalyzer archiveAnalyzer;

  Future<ShareThreatAnalysis> analyzeAsync(
    IncomingSharePayload payload, {
    QuarantineRecord? quarantine,
  }) async {
    if (payload.primaryType == IncomingShareContentType.image &&
        quarantine != null) {
      return imageAnalyzer.analyze(payload, quarantine);
    }
    if ((payload.primaryType == IncomingShareContentType.pdf ||
            payload.primaryType == IncomingShareContentType.document) &&
        quarantine != null) {
      return documentAnalyzer.analyzeAsync(payload, quarantine);
    }
    if (payload.primaryType == IncomingShareContentType.apk &&
        quarantine != null) {
      return apkAnalyzer.analyzeAsync(payload, quarantine);
    }
    if (payload.primaryType == IncomingShareContentType.archive &&
        quarantine != null) {
      return archiveAnalyzer.analyzeAsync(payload, quarantine);
    }
    return analyze(payload);
  }

  ShareThreatAnalysis analyze(IncomingSharePayload payload) {
    if (payload.hasOversizedAttachment) {
      return const ShareThreatAnalysis(
        risk: ShareThreatRisk.error,
        status: ShareAnalysisStatus.error,
        title: 'This file is too large to analyze safely',
        message:
            'Cyber Uday received the item, but its size exceeds the safe review limit.',
        indicators: <String>['The file was not copied, opened, or executed.'],
        recommendations: <String>[
          'Share a smaller item or use a trusted security workflow for large files.',
        ],
        analyzerName: 'Input size check',
      );
    }
    if (payload.hasInaccessibleAttachment) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.error,
        status: ShareAnalysisStatus.error,
        title: "We couldn't access this shared file",
        message: 'Please try sharing it again from the source app.',
        indicators: const <String>['The Android content URI was not readable.'],
        recommendations: const <String>[
          'Share the item again from the source application.',
        ],
        analyzerName: 'Input access check',
      );
    }

    for (final ShareAnalyzer analyzer in analyzers) {
      if (analyzer.canAnalyze(payload)) {
        return analyzer.analyze(payload);
      }
    }
    return const UnsupportedAnalyzer().analyzeWithoutMatch();
  }
}

class UrlAnalyzer implements ShareAnalyzer {
  const UrlAnalyzer({this.urlAnalysis = const UrlThreatAnalysisService()});

  final UrlThreatAnalysisService urlAnalysis;

  @override
  String get name => 'URL Threat Scanner';

  @override
  bool canAnalyze(IncomingSharePayload payload) => payload.urls.isNotEmpty;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) {
    final List<String> indicators = <String>[];
    final Map<String, List<String>> structuredEvidence =
        <String, List<String>>{};
    for (final String url in payload.urls) {
      final UrlThreatAnalysis analysis = urlAnalysis.analyze(
        url,
        surroundingText: payload.text,
      );
      indicators.addAll(analysis.indicators);
      analysis.localEvidence.forEach((category, entries) {
        structuredEvidence.update(
          category,
          (current) => <String>[...current, ...entries],
          ifAbsent: () => <String>[...entries],
        );
      });
      if (!analysis.normalization.isValid) {
        return ShareThreatAnalysis(
          risk: ShareThreatRisk.error,
          status: ShareAnalysisStatus.error,
          title: 'We could not validate this link',
          message:
              '${analysis.normalization.error} Cyber Uday did not open or follow it.',
          indicators: indicators,
          recommendations: const <String>[
            'Check the address with the sender through a trusted channel.',
          ],
          analyzerName: name,
          structuredEvidence: structuredEvidence,
        );
      }
    }
    final ShareThreatAnalysis result = _riskResult(
      analyzerName: name,
      indicators: indicators,
      suspiciousTitle: 'This link may be dangerous',
      safeMessage:
          'This local preliminary check found no common warning signs. It does not prove that the link is safe.',
    );
    return ShareThreatAnalysis(
      risk: result.risk,
      status: result.status,
      title: result.title,
      message: result.message,
      indicators: result.indicators,
      recommendations: result.recommendations,
      analyzerName: result.analyzerName,
      structuredEvidence: Map<String, List<String>>.unmodifiable(
        structuredEvidence.map(
          (key, value) => MapEntry<String, List<String>>(
            key,
            List<String>.unmodifiable(value),
          ),
        ),
      ),
      threatIntelligenceConfigured: false,
    );
  }
}

class TextThreatAnalyzer implements ShareAnalyzer {
  const TextThreatAnalyzer();

  @override
  String get name => 'Message Threat Scanner';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.text != null && payload.urls.isEmpty;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) {
    final String candidate = payload.text!.toLowerCase();
    final List<String> indicators = <String>[];
    for (final String term in _urgentTerms) {
      if (_containsWholeTerm(candidate, term)) {
        indicators.add('The message uses pressure language: "$term".');
      }
    }
    return _riskResult(
      analyzerName: name,
      indicators: indicators,
      suspiciousTitle: 'This message may be dangerous',
      safeMessage:
          'This local preliminary check found no common phishing or pressure signals. It does not prove that the message is safe.',
    );
  }
}

class ImageAnalyzer implements ShareAnalyzer {
  const ImageAnalyzer();

  @override
  String get name => 'Image Safety Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.primaryType == IncomingShareContentType.image;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) => _fileAnalysis(
    payload,
    name,
    'image',
    'OCR, QR-code, and screenshot inspection can be added through the isolated analyzer gateway.',
  );
}

/// Evidence extraction layer for quarantined images. OCR and QR payloads are
/// processed by the existing text and URL analyzers; this class does not make
/// a separate image verdict or ever open a discovered URL.
class ImageThreatAnalyzer {
  const ImageThreatAnalyzer({
    this.extractor = const LocalImageEvidenceExtractor(),
    this.urlAnalyzer = const UrlAnalyzer(),
    this.textAnalyzer = const TextThreatAnalyzer(),
  });

  final ImageEvidenceExtractor extractor;
  final UrlAnalyzer urlAnalyzer;
  final TextThreatAnalyzer textAnalyzer;

  Future<ShareThreatAnalysis> analyze(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async {
    final Map<int, QuarantinedContent> contentByIndex =
        <int, QuarantinedContent>{
          for (final QuarantinedContent content in quarantine.contents)
            content.attachmentIndex: content,
        };
    final Map<String, List<String>> evidence = <String, List<String>>{
      'IMAGE_FEATURES': <String>[],
      'OCR_RESULT': <String>[],
      'EXTRACTED_TEXT': <String>[],
      'EXTRACTED_URLS': <String>[],
      'QR_RESULT': <String>[],
      'TEXT_ANALYSIS': <String>[],
      'URL_ANALYSIS': <String>[],
    };
    final List<String> indicators = <String>[];
    final List<String> recommendations = <String>[
      'Do not open links or QR destinations from the image.',
      'Do not share passwords, OTPs, or banking details.',
    ];
    bool hasExtractedContent = false;
    bool hasIncompleteExtraction = false;
    int inspectedImages = 0;

    for (int index = 0; index < payload.attachments.length; index++) {
      final IncomingShareAttachment attachment = payload.attachments[index];
      if (attachment.contentType != IncomingShareContentType.image) continue;
      final QuarantinedContent? content = contentByIndex[index];
      if (content == null) {
        hasIncompleteExtraction = true;
        evidence['OCR_RESULT']!.add(
          'OCR_UNAVAILABLE: image ${index + 1} has no temporary local copy.',
        );
        evidence['QR_RESULT']!.add(
          'QR_UNAVAILABLE: image ${index + 1} has no temporary local copy.',
        );
        continue;
      }
      inspectedImages++;
      final ImageEvidenceExtraction extraction = await extractor.extract(
        content.reference,
      );
      evidence['IMAGE_FEATURES']!.add(
        'Image ${index + 1}: ${attachment.displayName}${_dimensionsLabel(extraction)}; decode ${extraction.decodeDurationMs} ms.',
      );
      evidence['OCR_RESULT']!.add(
        'Image ${index + 1}: ${extraction.status.name.toUpperCase()}; OCR ${extraction.ocrDurationMs} ms.',
      );
      evidence['QR_RESULT']!.add(
        'Image ${index + 1}: QR scan ${extraction.qrDurationMs} ms.',
      );
      for (final String message in extraction.messages) {
        if (message.startsWith('QR_')) {
          evidence['QR_RESULT']!.add(message);
        } else {
          evidence['OCR_RESULT']!.add(message);
        }
      }
      if (extraction.status != ImageExtractionStatus.complete) {
        hasIncompleteExtraction = true;
      }
      final String? text = extraction.ocrText?.trim();
      if (text != null && text.isNotEmpty) {
        hasExtractedContent = true;
        evidence['EXTRACTED_TEXT']!.add(_boundedText(text));
        final IncomingSharePayload textPayload = IncomingSharePayload(
          id: '${payload.id}-ocr-$index',
          receivedAt: payload.receivedAt,
          text: text,
          attachments: const <IncomingShareAttachment>[],
          sourceApplication: 'Local image OCR',
        );
        final ShareThreatAnalysis textResult = textAnalyzer.analyze(
          textPayload,
        );
        _addNestedIndicators(
          textResult,
          evidence['TEXT_ANALYSIS']!,
          indicators,
        );
        final List<String> urls = textPayload.urls;
        for (final String url in urls) {
          _addUrlAnalysis(url, payload, evidence, indicators);
        }
      }
      for (final String payloadValue in extraction.qrPayloads) {
        hasExtractedContent = true;
        evidence['QR_RESULT']!.add(
          'QR payload extracted: ${_boundedText(payloadValue)}',
        );
        if (_isLikelyUrl(payloadValue)) {
          _addUrlAnalysis(payloadValue, payload, evidence, indicators);
        } else {
          final ShareThreatAnalysis textResult = textAnalyzer.analyze(
            IncomingSharePayload(
              id: '${payload.id}-qr-$index',
              receivedAt: payload.receivedAt,
              text: payloadValue,
              attachments: const <IncomingShareAttachment>[],
              sourceApplication: 'Local QR extraction',
            ),
          );
          _addNestedIndicators(
            textResult,
            evidence['TEXT_ANALYSIS']!,
            indicators,
          );
        }
      }
    }

    if (inspectedImages == 0 || !hasExtractedContent) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'Image analysis is inconclusive',
        message:
            'Cyber Uday could not extract enough readable local evidence from this image. This is not treated as safe.',
        indicators: const <String>[
          'OCR or QR extraction did not provide security-relevant content.',
        ],
        recommendations: recommendations,
        analyzerName: 'Local Image Intelligence',
        structuredEvidence: _freezeEvidence(evidence),
      );
    }

    if (indicators.isEmpty && hasIncompleteExtraction) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'Image analysis is partial',
        message:
            'Cyber Uday extracted some local evidence, but a required OCR or QR check was incomplete. No safe verdict was assigned.',
        indicators: const <String>[
          'A partial image analysis is not treated as proof that the image is safe.',
        ],
        recommendations: recommendations,
        analyzerName: 'Local Image Intelligence',
        structuredEvidence: _freezeEvidence(evidence),
      );
    }

    final ShareThreatAnalysis result = _riskResult(
      analyzerName: 'Local Image Intelligence',
      indicators: indicators,
      suspiciousTitle: 'This image contains warning signs',
      safeMessage:
          'No common threat indicators were found in the locally extracted image text. This does not prove that the image or any sender is safe.',
    );
    return ShareThreatAnalysis(
      risk: result.risk,
      status: result.status,
      title: result.title,
      message: result.message,
      indicators: result.indicators,
      recommendations: <String>[...result.recommendations, ...recommendations],
      analyzerName: result.analyzerName,
      structuredEvidence: _freezeEvidence(evidence),
    );
  }

  void _addUrlAnalysis(
    String url,
    IncomingSharePayload payload,
    Map<String, List<String>> evidence,
    List<String> indicators,
  ) {
    final ShareThreatAnalysis urlResult = urlAnalyzer.analyze(
      IncomingSharePayload.fromManualUrl(url, note: payload.text),
    );
    evidence['EXTRACTED_URLS']!.add(url);
    _addNestedIndicators(urlResult, evidence['URL_ANALYSIS']!, indicators);
  }
}

void _addNestedIndicators(
  ShareThreatAnalysis result,
  List<String> destination,
  List<String> indicators,
) {
  if (result.status == ShareAnalysisStatus.safe) {
    destination.add(
      'No local threat indicators were found by ${result.analyzerName}.',
    );
    return;
  }
  destination.addAll(result.indicators);
  indicators.addAll(result.indicators);
}

Map<String, List<String>> _freezeEvidence(Map<String, List<String>> evidence) =>
    Map<String, List<String>>.unmodifiable(
      evidence.map(
        (key, value) => MapEntry<String, List<String>>(
          key,
          List<String>.unmodifiable(value),
        ),
      ),
    );

String _dimensionsLabel(ImageEvidenceExtraction extraction) =>
    extraction.width == null || extraction.height == null
    ? ''
    : ' (${extraction.width}x${extraction.height})';

String _boundedText(String value) =>
    value.length <= 2000 ? value : '${value.substring(0, 2000)} [truncated]';

bool _isLikelyUrl(String value) {
  final String candidate = value.trim();
  return candidate.startsWith('http://') ||
      candidate.startsWith('https://') ||
      candidate.startsWith('www.') ||
      RegExp(
        r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:[/?#:]|$)',
      ).hasMatch(candidate);
}

bool _containsWholeTerm(String value, String term) => RegExp(
  '\\b${RegExp.escape(term)}\\b',
  caseSensitive: false,
).hasMatch(value);

class DocumentAnalyzer implements ShareAnalyzer {
  const DocumentAnalyzer({
    this.intelligence = const LocalDocumentIntelligence(),
    this.urlAnalyzer = const UrlAnalyzer(),
    this.textAnalyzer = const TextThreatAnalyzer(),
  });

  final DocumentIntelligence intelligence;
  final UrlAnalyzer urlAnalyzer;
  final TextThreatAnalyzer textAnalyzer;

  @override
  String get name => 'Document Safety Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.primaryType == IncomingShareContentType.pdf ||
      payload.primaryType == IncomingShareContentType.document;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) => _fileAnalysis(
    payload,
    name,
    payload.primaryType.label,
    'Metadata, text extraction, embedded URL, and document-structure inspection can be added through the isolated analyzer gateway.',
  );

  Future<ShareThreatAnalysis> analyzeAsync(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async {
    final Map<int, QuarantinedContent> contentByIndex =
        <int, QuarantinedContent>{
          for (final QuarantinedContent content in quarantine.contents)
            content.attachmentIndex: content,
        };
    final Map<String, List<String>> evidence = <String, List<String>>{};
    final List<String> indicators = <String>[];
    final List<String> recommendations = <String>[
      'Do not open links or launch attachments from this document.',
      'Do not provide passwords, OTPs, or banking details in response to it.',
      'Verify the sender independently before taking action.',
    ];
    bool hasUnknownResult = false;
    bool hasPartialResult = false;
    bool hasThreatIndicator = false;
    int inspectedDocuments = 0;

    for (int index = 0; index < payload.attachments.length; index++) {
      final IncomingShareAttachment attachment = payload.attachments[index];
      if (attachment.contentType != IncomingShareContentType.pdf &&
          attachment.contentType != IncomingShareContentType.document) {
        continue;
      }
      inspectedDocuments++;
      final QuarantinedContent? content = contentByIndex[index];
      if (content == null) {
        hasUnknownResult = true;
        _addEvidence(
          evidence,
          'PDF_ANALYSIS_STATUS',
          'DOCUMENT_SOURCE_UNAVAILABLE: no local quarantine copy was available.',
        );
        continue;
      }
      final DocumentIntelligenceResult document = await intelligence.analyze(
        reference: content.reference,
        fileName: attachment.displayName,
        mimeType: attachment.mimeType,
      );
      _mergeEvidence(evidence, document.evidence);
      hasUnknownResult =
          hasUnknownResult ||
          document.status == DocumentIntelligenceStatus.unknown ||
          document.status == DocumentIntelligenceStatus.unsupported;
      hasPartialResult =
          hasPartialResult ||
          document.status == DocumentIntelligenceStatus.partial;
      indicators.addAll(document.indicators);

      final String? extractedText = document.extractedText?.trim();
      if (extractedText != null && extractedText.isNotEmpty) {
        final ShareThreatAnalysis textResult = textAnalyzer.analyze(
          IncomingSharePayload(
            id: '${payload.id}-document-text-$index',
            receivedAt: payload.receivedAt,
            text: extractedText,
            attachments: const <IncomingShareAttachment>[],
            sourceApplication: 'Local document text extraction',
          ),
        );
        _addNestedIndicators(
          textResult,
          evidence.putIfAbsent('TEXT_ANALYSIS', () => <String>[]),
          indicators,
        );
        hasThreatIndicator =
            hasThreatIndicator || textResult.indicators.any(_isThreatIndicator);
      }

      for (final String url in document.extractedUrls) {
        final ShareThreatAnalysis urlResult = urlAnalyzer.analyze(
          IncomingSharePayload.fromManualUrl(url, note: extractedText),
        );
        _addEvidence(evidence, 'EXTRACTED_URLS', url);
        _addNestedIndicators(
          urlResult,
          evidence.putIfAbsent('URL_ANALYSIS', () => <String>[]),
          indicators,
        );
        hasThreatIndicator =
            hasThreatIndicator || urlResult.indicators.any(_isThreatIndicator);
      }
      final List<String> activeIndicators = <String>[
        for (final String item in document.indicators)
          if (_isActiveContentIndicator(item)) item,
      ];
      hasThreatIndicator = hasThreatIndicator || activeIndicators.isNotEmpty;
    }

    if (inspectedDocuments == 0 ||
        hasUnknownResult ||
        (hasPartialResult && !hasThreatIndicator)) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'Document analysis is inconclusive',
        message:
            'Cyber Uday could not establish a reliable conclusion from this document. It was not opened, executed, or sent to external AI.',
        indicators: List<String>.unmodifiable(<String>[
          ...indicators,
          'INCOMPLETE_ANALYSIS: unknown or unsupported document evidence is not treated as safe.',
        ]),
        recommendations: recommendations,
        analyzerName: name,
        structuredEvidence: _freezeEvidence(evidence),
      );
    }

    final ShareThreatAnalysis result = _riskResult(
      analyzerName: name,
      indicators: indicators.where(_isThreatIndicator).toList(),
      suspiciousTitle: 'This document contains warning signs',
      safeMessage:
          'No common warning signs were found in the locally extracted document evidence. This does not prove that the document or sender is safe.',
    );
    return ShareThreatAnalysis(
      risk: result.risk,
      status: hasPartialResult ? ShareAnalysisStatus.partial : result.status,
      title: result.title,
      message: result.message,
      indicators: result.indicators,
      recommendations: <String>[...result.recommendations, ...recommendations],
      analyzerName: result.analyzerName,
      structuredEvidence: _freezeEvidence(evidence),
    );
  }
}

class ApkAnalyzer implements ShareAnalyzer {
  const ApkAnalyzer({
    this.intelligence = const LocalApkStaticAnalyzer(),
    this.urlAnalyzer = const UrlAnalyzer(),
    this.textAnalyzer = const TextThreatAnalyzer(),
  });

  final ApkStaticAnalyzer intelligence;
  final UrlAnalyzer urlAnalyzer;
  final TextThreatAnalyzer textAnalyzer;

  @override
  String get name => 'APK Static Analysis Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.primaryType == IncomingShareContentType.apk;

  @override
  ShareThreatAnalysis analyze(
    IncomingSharePayload payload,
  ) => ShareThreatAnalysis(
    risk: ShareThreatRisk.unsupported,
    status: ShareAnalysisStatus.analysisUnavailable,
    title: 'APK received safely',
    message:
        'Cyber Uday can prepare this Android application for security analysis. It has not installed, launched, or executed it.',
    indicators: const <String>[
      'Package, permission, signing, manifest, and hash inspection are reserved for the isolated analyzer.',
    ],
    recommendations: const <String>[
      'Do not install or open the APK.',
      'Wait for static analysis or verify its source independently.',
    ],
    analyzerName: 'APK Static Analysis Intake',
  );

  Future<ShareThreatAnalysis> analyzeAsync(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async {
    final Map<int, QuarantinedContent> contentByIndex =
        <int, QuarantinedContent>{
          for (final QuarantinedContent content in quarantine.contents)
            content.attachmentIndex: content,
        };
    final Map<String, List<String>> evidence = <String, List<String>>{};
    final List<String> threatIndicators = <String>[];
    final List<String> recommendations = <String>[
      'Do not install or open this APK.',
      'Do not grant accessibility, overlay, device-admin, or install permissions unless independently verified.',
      'Do not enter passwords, OTPs, banking details, or wallet recovery phrases into the application.',
      'Verify the publisher and download source through a trusted channel.',
    ];
    bool hasUnknown = false;
    bool hasPartial = false;
    bool inspected = false;

    for (int index = 0; index < payload.attachments.length; index++) {
      final IncomingShareAttachment attachment = payload.attachments[index];
      if (attachment.contentType != IncomingShareContentType.apk) continue;
      inspected = true;
      final QuarantinedContent? content = contentByIndex[index];
      if (content == null) {
        hasUnknown = true;
        _addEvidence(evidence, 'APK_ANALYSIS_STATUS', 'APK_SOURCE_UNAVAILABLE');
        continue;
      }
      final ApkStaticAnalysisResult result = await intelligence.analyze(
        reference: content.reference,
        fileName: attachment.displayName,
        mimeType: attachment.mimeType,
      );
      _mergeEvidence(evidence, result.evidence);
      hasUnknown = hasUnknown || result.status == ApkAnalysisStatus.unknown;
      hasPartial = hasPartial || result.status == ApkAnalysisStatus.partial;
      threatIndicators.addAll(result.indicators.where(_isApkThreatIndicator));

      for (final String url in result.extractedUrls) {
        final UrlThreatAnalysis urlResult = urlAnalyzer.urlAnalysis.analyze(
          url,
        );
        _addEvidence(evidence, 'APK_URL_ANALYSIS', url);
        _mergeEvidence(evidence, urlResult.localEvidence);
        if (_urlHasWarning(urlResult)) {
          threatIndicators.add('APK_SUSPICIOUS_URL: $url');
        }
      }
      for (final String sample in result.textSamples.take(50)) {
        final ShareThreatAnalysis textResult = textAnalyzer.analyze(
          IncomingSharePayload(
            id: '${payload.id}-apk-text-$index',
            receivedAt: payload.receivedAt,
            text: sample,
            attachments: const <IncomingShareAttachment>[],
            sourceApplication: 'Local APK string extraction',
          ),
        );
        if (textResult.indicators.any(_isThreatIndicator)) {
          threatIndicators.addAll(
            textResult.indicators.map((item) => 'APK_TEXT: $item'),
          );
        }
      }
    }

    if (!inspected || hasUnknown || (hasPartial && threatIndicators.isEmpty)) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'APK analysis is inconclusive',
        message:
            'Cyber Uday completed only a partial static review. The APK was not installed, launched, or executed, and this result is not a safe verdict.',
        indicators: List<String>.unmodifiable(<String>[
          ...threatIndicators,
          'APK_ANALYSIS_INCOMPLETE: insufficient evidence is not treated as safe.',
        ]),
        recommendations: recommendations,
        analyzerName: name,
        structuredEvidence: _freezeEvidence(evidence),
      );
    }

    final ShareThreatAnalysis result = _riskResult(
      analyzerName: name,
      indicators: threatIndicators,
      suspiciousTitle: 'This APK contains warning signs',
      safeMessage:
          'No common warning signs were found during this bounded static review. This does not prove that the APK is safe.',
    );
    return ShareThreatAnalysis(
      risk: result.risk,
      status: hasPartial ? ShareAnalysisStatus.partial : result.status,
      title: result.title,
      message: result.message,
      indicators: result.indicators,
      recommendations: <String>[...result.recommendations, ...recommendations],
      analyzerName: result.analyzerName,
      structuredEvidence: _freezeEvidence(evidence),
    );
  }
}

class ArchiveAnalyzer implements ShareAnalyzer {
  const ArchiveAnalyzer({
    this.intelligence = const LocalArchiveStaticAnalyzer(),
    this.urlAnalyzer = const UrlAnalyzer(),
    this.textAnalyzer = const TextThreatAnalyzer(),
  });

  final ArchiveStaticAnalyzer intelligence;
  final UrlAnalyzer urlAnalyzer;
  final TextThreatAnalyzer textAnalyzer;

  @override
  String get name => 'Archive Static Analysis Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.primaryType == IncomingShareContentType.archive;

  @override
  ShareThreatAnalysis analyze(
    IncomingSharePayload payload,
  ) => const ShareThreatAnalysis(
    risk: ShareThreatRisk.unsupported,
    status: ShareAnalysisStatus.analysisUnavailable,
    title: 'Archive analysis is unavailable',
    message:
        'Cyber Uday received this archive safely, but a bounded ZIP inspection was not available for this platform. It was not opened or executed.',
    indicators: <String>['ARCHIVE_ANALYSIS_UNAVAILABLE'],
    recommendations: <String>[
      'Keep the archive closed until it can be inspected safely.',
    ],
    analyzerName: 'Archive Static Analysis Intake',
  );

  Future<ShareThreatAnalysis> analyzeAsync(
    IncomingSharePayload payload,
    QuarantineRecord quarantine,
  ) async {
    final Map<int, QuarantinedContent> contentByIndex =
        <int, QuarantinedContent>{
          for (final QuarantinedContent content in quarantine.contents)
            content.attachmentIndex: content,
        };
    final Map<String, List<String>> evidence = <String, List<String>>{};
    final List<String> threatIndicators = <String>[];
    final List<String> recommendations = <String>[
      'Do not open or execute files from this archive.',
      'Verify the sender and source independently before extracting anything.',
      'Do not install APKs or run scripts found inside the archive.',
    ];
    bool hasUnknown = false;
    bool hasPartial = false;
    bool inspected = false;

    for (int index = 0; index < payload.attachments.length; index++) {
      final IncomingShareAttachment attachment = payload.attachments[index];
      if (attachment.contentType != IncomingShareContentType.archive) continue;
      inspected = true;
      final QuarantinedContent? content = contentByIndex[index];
      if (content == null) {
        hasUnknown = true;
        _addEvidence(
          evidence,
          'ARCHIVE_ANALYSIS_STATUS',
          'ARCHIVE_SOURCE_UNAVAILABLE',
        );
        continue;
      }
      final ArchiveStaticAnalysisResult result = await intelligence.analyze(
        reference: content.reference,
        fileName: attachment.displayName,
        mimeType: attachment.mimeType,
      );
      _mergeEvidence(evidence, result.evidence);
      hasUnknown =
          hasUnknown ||
          result.status == ArchiveAnalysisStatus.unknown ||
          result.status == ArchiveAnalysisStatus.unsupported;
      hasPartial = hasPartial || result.status == ArchiveAnalysisStatus.partial;
      hasUnknown =
          hasUnknown ||
          result.apkResults.any(
            (ApkStaticAnalysisResult apk) =>
                apk.status == ApkAnalysisStatus.unknown ||
                apk.status == ApkAnalysisStatus.unsupported,
          );
      hasPartial =
          hasPartial ||
          result.apkResults.any(
            (ApkStaticAnalysisResult apk) =>
                apk.status == ApkAnalysisStatus.partial,
          );
      threatIndicators.addAll(
        result.indicators.where(_isArchiveThreatIndicator),
      );

      for (final String url in result.extractedUrls) {
        final UrlThreatAnalysis urlResult = urlAnalyzer.urlAnalysis.analyze(
          url,
        );
        _addEvidence(evidence, 'ARCHIVE_URL_ANALYSIS', url);
        _mergeEvidence(evidence, urlResult.localEvidence);
        if (_urlHasWarning(urlResult)) {
          threatIndicators.add('ARCHIVE_SUSPICIOUS_URL: $url');
        }
      }
      for (final String sample in result.textSamples) {
        final ShareThreatAnalysis textResult = textAnalyzer.analyze(
          IncomingSharePayload(
            id: '${payload.id}-archive-text-$index',
            receivedAt: payload.receivedAt,
            text: sample,
            attachments: const <IncomingShareAttachment>[],
            sourceApplication: 'Local archive text extraction',
          ),
        );
        if (textResult.indicators.any(_isThreatIndicator)) {
          threatIndicators.addAll(
            textResult.indicators.map((item) => 'ARCHIVE_TEXT: $item'),
          );
        }
      }
    }

    if (!inspected || hasUnknown || (hasPartial && threatIndicators.isEmpty)) {
      return ShareThreatAnalysis(
        risk: ShareThreatRisk.unsupported,
        status: ShareAnalysisStatus.analysisUnavailable,
        title: 'Archive analysis is inconclusive',
        message:
            'Cyber Uday completed only a bounded partial review. The archive was not opened or executed, and this is not a safe verdict.',
        indicators: List<String>.unmodifiable(<String>[
          ...threatIndicators,
          'ARCHIVE_ANALYSIS_INCOMPLETE: insufficient evidence is not treated as safe.',
        ]),
        recommendations: recommendations,
        analyzerName: name,
        structuredEvidence: _freezeEvidence(evidence),
      );
    }
    final ShareThreatAnalysis result = _riskResult(
      analyzerName: name,
      indicators: threatIndicators,
      suspiciousTitle: 'This archive contains warning signs',
      safeMessage:
          'No common warning signs were found in the bounded archive inventory. This does not prove that the archive or its contents are safe.',
    );
    return ShareThreatAnalysis(
      risk: result.risk,
      status: hasPartial ? ShareAnalysisStatus.partial : result.status,
      title: result.title,
      message: result.message,
      indicators: result.indicators,
      recommendations: <String>[...result.recommendations, ...recommendations],
      analyzerName: result.analyzerName,
      structuredEvidence: _freezeEvidence(evidence),
    );
  }
}

class MediaAnalyzer implements ShareAnalyzer {
  const MediaAnalyzer();

  @override
  String get name => 'Media Safety Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) =>
      payload.primaryType == IncomingShareContentType.audio ||
      payload.primaryType == IncomingShareContentType.video;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) => _fileAnalysis(
    payload,
    name,
    payload.primaryType.label,
    'Media metadata and future safe transcription or frame inspection can be added through the isolated analyzer gateway.',
  );
}

class UnsupportedAnalyzer implements ShareAnalyzer {
  const UnsupportedAnalyzer();

  @override
  String get name => 'General File Safety Intake';

  @override
  bool canAnalyze(IncomingSharePayload payload) => true;

  @override
  ShareThreatAnalysis analyze(IncomingSharePayload payload) =>
      analyzeWithoutMatch();

  ShareThreatAnalysis analyzeWithoutMatch() => const ShareThreatAnalysis(
    risk: ShareThreatRisk.unsupported,
    status: ShareAnalysisStatus.analysisUnavailable,
    title: 'File received',
    message:
        'Cyber Uday received this item safely but does not currently have a dedicated analyzer for this format. It has not opened or executed the file.',
    indicators: <String>['The content remains untrusted input.'],
    recommendations: <String>[
      'Do not open or execute the file until its source is verified.',
    ],
    analyzerName: 'General File Safety Intake',
  );
}

ShareThreatAnalysis _fileAnalysis(
  IncomingSharePayload payload,
  String analyzerName,
  String type,
  String futureCapability,
) => ShareThreatAnalysis(
  risk: ShareThreatRisk.unsupported,
  status: ShareAnalysisStatus.analysisUnavailable,
  title: '${type[0].toUpperCase()}${type.substring(1)} received safely',
  message:
      'Cyber Uday received this $type safely. Deep analysis is not available on the device yet. The item was not opened or executed.',
  indicators: <String>[
    'Only filename, MIME type, and size were reviewed.',
    futureCapability,
    if (payload.attachments.length > 1)
      '${payload.attachments.length} related items remain grouped for future analysis.',
  ],
  recommendations: const <String>[
    'Keep the item closed until its source is verified.',
    'Do not enter credentials or run instructions from the content.',
  ],
  analyzerName: analyzerName,
);

void _mergeEvidence(
  Map<String, List<String>> destination,
  Map<String, List<String>> source,
) {
  for (final MapEntry<String, List<String>> entry in source.entries) {
    destination.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
  }
}

void _addEvidence(
  Map<String, List<String>> evidence,
  String category,
  String value,
) {
  evidence.putIfAbsent(category, () => <String>[]).add(value);
}

bool _isThreatIndicator(String value) {
  final String candidate = value.toLowerCase();
  const List<String> analysisOnly = <String>[
    'pdf_analysis_',
    'incomplete_analysis',
    'encrypted_document',
    'pdf_resource_limit',
    'document_source_unavailable',
    'unsupported_format',
    'empty_document',
    'text_extraction_unavailable',
    'binary_document',
  ];
  if (analysisOnly.any(candidate.startsWith)) return false;
  return value.trim().isNotEmpty;
}

bool _isApkThreatIndicator(String value) {
  final String candidate = value.toLowerCase();
  const List<String> analysisOnly = <String>[
    'apk_analysis_',
    'apk_invalid_input',
    'apk_source_unavailable',
    'apk_size_limit',
    'apk_manifest_analysis_incomplete',
    'apk_dex_analysis_incomplete',
    'signature_analysis_unavailable',
  ];
  if (analysisOnly.any(candidate.startsWith)) return false;
  return value.trim().isNotEmpty;
}

bool _isArchiveThreatIndicator(String value) {
  final String candidate = value.toLowerCase();
  const List<String> analysisOnly = <String>[
    'archive_analysis_',
    'archive_invalid_input',
    'archive_source_unavailable',
    'archive_size_limit',
    'archive_inspected_bytes_limit',
  ];
  return !analysisOnly.any(candidate.startsWith) && value.trim().isNotEmpty;
}

bool _urlHasWarning(UrlThreatAnalysis analysis) {
  final String evidence = analysis.indicators.join(' ').toLowerCase();
  return evidence.contains('ip address') ||
      evidence.contains('punycode') ||
      evidence.contains('shortener') ||
      evidence.contains('credential') ||
      evidence.contains('phishing') ||
      evidence.contains('suspicious') ||
      evidence.contains('non-https') ||
      evidence.contains('excessive');
}

bool _isActiveContentIndicator(String value) {
  final String candidate = value.toLowerCase();
  return candidate.contains('javascript_indicator') ||
      candidate.contains('embedded_file_indicator') ||
      candidate.contains('launch_action_indicator') ||
      candidate.contains('automatic_action_indicator') ||
      candidate.contains('form_indicator') ||
      candidate.contains('annotation_indicator');
}

ShareThreatAnalysis _riskResult({
  required String analyzerName,
  required List<String> indicators,
  required String suspiciousTitle,
  required String safeMessage,
}) {
  if (indicators.length >= 3) {
    return ShareThreatAnalysis(
      risk: ShareThreatRisk.highRisk,
      status: ShareAnalysisStatus.highRisk,
      title: 'Do not open this yet',
      message:
          'Several common scam indicators were found in this shared content.',
      indicators: indicators,
      recommendations: const <String>[
        'Do not open the link or reply to the message.',
        'Do not enter passwords, OTPs, or banking details.',
        'Save a report and contact the organization through a trusted channel.',
      ],
      analyzerName: analyzerName,
    );
  }
  if (indicators.isNotEmpty) {
    return ShareThreatAnalysis(
      risk: ShareThreatRisk.suspicious,
      status: ShareAnalysisStatus.suspicious,
      title: suspiciousTitle,
      message:
          'Review the warning signs before opening the link or replying to the sender.',
      indicators: indicators,
      recommendations: const <String>[
        'Verify the sender independently.',
        'Do not share passwords, OTPs, or financial information.',
      ],
      analyzerName: analyzerName,
    );
  }
  return ShareThreatAnalysis(
    risk: ShareThreatRisk.safe,
    status: ShareAnalysisStatus.safe,
    title: 'No obvious threat detected',
    message: safeMessage,
    indicators: const <String>[
      'No external website, file, or message was opened during this check.',
    ],
    recommendations: const <String>[
      'Continue only if you recognize and trust the sender.',
    ],
    analyzerName: analyzerName,
  );
}

const List<String> _urgentTerms = <String>[
  'urgent',
  'verify',
  'blocked',
  'suspended',
  'otp',
  'password',
  'kyc',
  'reward',
  'prize',
  'refund',
  'bank account',
];
