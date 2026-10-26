import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'document_intelligence_models.dart';
import 'security_pipeline_config.dart';

/// Performs bounded, local, static inspection only. It never launches a PDF,
/// follows a URL, executes JavaScript, or opens an embedded object.
class LocalDocumentIntelligence implements DocumentIntelligence {
  const LocalDocumentIntelligence({
    this.config = const SecurityPipelineConfig(),
  });

  final SecurityPipelineConfig config;

  @override
  Future<DocumentIntelligenceResult> analyze({
    required String reference,
    required String fileName,
    required String? mimeType,
  }) async {
    final Stopwatch total = Stopwatch()..start();
    final File? source = _fileFromReference(reference);
    if (source == null || !await source.exists()) {
      return _unknown(
        fileName,
        total.elapsedMilliseconds,
        'DOCUMENT_SOURCE_UNAVAILABLE: local quarantine copy was not readable.',
      );
    }

    final int size = await source.length();
    if (size == 0) {
      return _unknown(
        fileName,
        total.elapsedMilliseconds,
        'EMPTY_DOCUMENT: the quarantined document contains no bytes.',
      );
    }
    if (size > config.maxFileSizeBytes) {
      return _partial(
        fileName,
        total.elapsedMilliseconds,
        'FILE_SIZE_LIMIT: document exceeds the bounded PDF/document size limit.',
      );
    }

    final Uint8List bytes = await source.readAsBytes();
    final String extension = _extension(fileName);
    final bool isPdf =
        _looksLikePdf(bytes) ||
        mimeType?.toLowerCase() == 'application/pdf' ||
        extension == 'pdf';
    if (isPdf) return _analyzePdf(bytes, total);
    if (_isSupportedTextDocument(extension, mimeType)) {
      return _analyzeTextDocument(bytes, fileName, total);
    }
    return DocumentIntelligenceResult(
      status: DocumentIntelligenceStatus.unsupported,
      documentType: 'document',
      evidence: <String, List<String>>{
        'DOCUMENT_FEATURES': <String>[
          'UNSUPPORTED_FORMAT: this document format has no safe local parser.',
        ],
        'DOCUMENT_ANALYSIS_STATUS': <String>['UNSUPPORTED'],
      },
      extractedUrls: const <String>[],
      indicators: const <String>[
        'The document format is not supported for local static inspection.',
      ],
      metadata: const DocumentMetadata(),
      timingsMs: <String, int>{'total': total.elapsedMilliseconds},
      error: 'Unsupported document format.',
    );
  }

  DocumentIntelligenceResult _analyzePdf(Uint8List bytes, Stopwatch total) {
    final Stopwatch structureTimer = Stopwatch()..start();
    final String source = _latin1(bytes);
    final String? version = RegExp(
      r'%PDF-([0-9]+\.[0-9]+)',
    ).firstMatch(source)?.group(1);
    final bool signature = _looksLikePdf(bytes);
    final bool eof = _hasPdfEof(bytes);
    final int objectCount = RegExp(
      r'\b[0-9]+\s+[0-9]+\s+obj\b',
    ).allMatches(source).length;
    final int pageCount = RegExp(r'/Type\s*/Page\b').allMatches(source).length;
    final bool encrypted = RegExp(r'/Encrypt\b').hasMatch(source);
    final Map<String, List<String>> evidence = <String, List<String>>{
      'PDF_FEATURES': <String>[
        'SIGNATURE: ${signature ? 'PDF' : 'MISSING'}',
        'VERSION: ${version ?? 'UNKNOWN'}',
        'OBJECTS: $objectCount',
        'PAGES: $pageCount',
      ],
      'PDF_STRUCTURE': <String>[],
      'PDF_METADATA': <String>[],
      'PDF_TEXT': <String>[],
      'PDF_URLS': <String>[],
      'PDF_ACTIVE_CONTENT': <String>[],
      'PDF_EMBEDDED_CONTENT': <String>[],
      'PDF_ANALYSIS_STATUS': <String>[],
      'PDF_PERFORMANCE': <String>[],
    };
    final List<String> indicators = <String>[];
    final bool structurallyValid = signature && eof && objectCount > 0;
    if (structurallyValid) {
      evidence['PDF_STRUCTURE']!.add(
        'STRUCTURE: basic PDF signature, objects, and EOF marker are present.',
      );
    } else {
      if (!signature) {
        evidence['PDF_STRUCTURE']!.add('MALFORMED: PDF signature is missing.');
      }
      if (!eof) {
        evidence['PDF_STRUCTURE']!.add('MALFORMED: PDF EOF marker is missing.');
      }
      if (objectCount == 0) {
        evidence['PDF_STRUCTURE']!.add('MALFORMED: no PDF objects were found.');
      }
    }
    if (encrypted) {
      evidence['PDF_STRUCTURE']!.add(
        'ENCRYPTED: /Encrypt is present; document content could not be fully inspected.',
      );
      indicators.add(
        'ENCRYPTED_DOCUMENT: password-protected content could not be fully inspected.',
      );
    }
    final bool pageLimitExceeded = pageCount > config.maxPdfPages;
    final bool objectLimitExceeded = objectCount > config.maxPdfObjects;
    if (pageLimitExceeded) {
      evidence['PDF_STRUCTURE']!.add(
        'PAGE_LIMIT: page count exceeds the bounded PDF page limit.',
      );
      indicators.add(
        'PDF_RESOURCE_LIMIT: page count exceeded the safe inspection limit.',
      );
    }
    if (objectLimitExceeded) {
      evidence['PDF_STRUCTURE']!.add(
        'OBJECT_LIMIT: object count exceeds the bounded PDF object limit.',
      );
      indicators.add(
        'PDF_RESOURCE_LIMIT: object count exceeded the safe inspection limit.',
      );
    }
    final int structureMs = structureTimer.elapsedMilliseconds;

    final Stopwatch metadataTimer = Stopwatch()..start();
    final DocumentMetadata metadata = DocumentMetadata(
      title: _pdfInfoValue(source, 'Title'),
      author: _pdfInfoValue(source, 'Author'),
      creator: _pdfInfoValue(source, 'Creator'),
      producer: _pdfInfoValue(source, 'Producer'),
      creationDate: _pdfInfoValue(source, 'CreationDate'),
      modificationDate: _pdfInfoValue(source, 'ModDate'),
      pageCount: pageCount == 0 ? null : pageCount,
      pdfVersion: version,
    );
    _addMetadataEvidence(evidence['PDF_METADATA']!, metadata);
    final int metadataMs = metadataTimer.elapsedMilliseconds;

    final Stopwatch textTimer = Stopwatch()..start();
    final String extractedText = _extractPdfText(source);
    final String boundedText =
        extractedText.length > config.maxDocumentTextCharacters
        ? extractedText.substring(0, config.maxDocumentTextCharacters)
        : extractedText;
    if (boundedText.trim().isEmpty) {
      evidence['PDF_TEXT']!.add(
        'TEXT_EXTRACTION_UNAVAILABLE: no visible text operators were found.',
      );
    } else {
      evidence['PDF_TEXT']!.add(
        'PDF_TEXT: ${boundedText.length} characters extracted locally.',
      );
      if (boundedText.length != extractedText.length) {
        evidence['PDF_TEXT']!.add(
          'TEXT_LIMIT: extracted text was bounded before analysis.',
        );
      }
    }
    final int textMs = textTimer.elapsedMilliseconds;

    final Stopwatch urlTimer = Stopwatch()..start();
    final List<String> urls = _extractUrls('$boundedText\n$source');
    for (final String url in urls) {
      evidence['PDF_URLS']!.add('EXTRACTED_URL: $url');
    }
    final int urlMs = urlTimer.elapsedMilliseconds;

    final Stopwatch activeTimer = Stopwatch()..start();
    _addTokenEvidence(source, evidence, indicators);
    final int activeMs = activeTimer.elapsedMilliseconds;

    final bool incomplete =
        !structurallyValid ||
        encrypted ||
        pageLimitExceeded ||
        objectLimitExceeded;
    final DocumentIntelligenceStatus status = !structurallyValid
        ? DocumentIntelligenceStatus.unknown
        : incomplete || boundedText.trim().isEmpty
        ? DocumentIntelligenceStatus.partial
        : DocumentIntelligenceStatus.complete;
    evidence['PDF_ANALYSIS_STATUS']!.add(status.name.toUpperCase());
    evidence['PDF_PERFORMANCE']!.addAll(<String>[
      'structure: $structureMs ms',
      'metadata: $metadataMs ms',
      'text: $textMs ms',
      'urls: $urlMs ms',
      'active-content: $activeMs ms',
      'total: ${total.elapsedMilliseconds} ms',
    ]);
    if (status != DocumentIntelligenceStatus.complete) {
      indicators.add(
        'PDF_ANALYSIS_PARTIAL: the result is incomplete and is not treated as safe.',
      );
    }
    return DocumentIntelligenceResult(
      status: status,
      documentType: 'pdf',
      evidence: _freezeEvidence(evidence),
      extractedUrls: List<String>.unmodifiable(urls),
      indicators: List<String>.unmodifiable(indicators),
      metadata: metadata,
      timingsMs: <String, int>{
        'structure': structureMs,
        'metadata': metadataMs,
        'text': textMs,
        'urls': urlMs,
        'activeContent': activeMs,
        'total': total.elapsedMilliseconds,
      },
      extractedText: boundedText.trim().isEmpty ? null : boundedText,
      encrypted: encrypted,
    );
  }

  DocumentIntelligenceResult _analyzeTextDocument(
    Uint8List bytes,
    String fileName,
    Stopwatch total,
  ) {
    final String content = utf8.decode(bytes, allowMalformed: true);
    if (content.contains('\u0000')) {
      return _unknown(
        fileName,
        total.elapsedMilliseconds,
        'BINARY_DOCUMENT: text document contains binary bytes.',
      );
    }
    final String bounded = content.length > config.maxDocumentTextCharacters
        ? content.substring(0, config.maxDocumentTextCharacters)
        : content;
    final List<String> urls = _extractUrls(bounded);
    final Map<String, List<String>> evidence = <String, List<String>>{
      'DOCUMENT_FEATURES': <String>['TEXT_DOCUMENT: $fileName'],
      'PDF_TEXT': <String>[
        'DOCUMENT_TEXT: ${bounded.length} characters extracted locally.',
      ],
      'PDF_URLS': <String>[
        for (final String url in urls) 'EXTRACTED_URL: $url',
      ],
      'PDF_ANALYSIS_STATUS': <String>['COMPLETE'],
      'PDF_PERFORMANCE': <String>['total: ${total.elapsedMilliseconds} ms'],
    };
    if (bounded.trim().isEmpty) {
      return _partial(
        fileName,
        total.elapsedMilliseconds,
        'TEXT_EXTRACTION_UNAVAILABLE: document is empty.',
      );
    }
    return DocumentIntelligenceResult(
      status: DocumentIntelligenceStatus.complete,
      documentType: 'text-document',
      evidence: _freezeEvidence(evidence),
      extractedUrls: List<String>.unmodifiable(urls),
      indicators: const <String>[],
      metadata: const DocumentMetadata(),
      timingsMs: <String, int>{'total': total.elapsedMilliseconds},
      extractedText: bounded,
    );
  }

  DocumentIntelligenceResult _unknown(
    String fileName,
    int elapsed,
    String reason,
  ) => DocumentIntelligenceResult(
    status: DocumentIntelligenceStatus.unknown,
    documentType: _extension(fileName) == 'pdf' ? 'pdf' : 'document',
    evidence: <String, List<String>>{
      'PDF_ANALYSIS_STATUS': <String>['UNKNOWN', reason],
    },
    extractedUrls: const <String>[],
    indicators: <String>[reason],
    metadata: const DocumentMetadata(),
    timingsMs: <String, int>{'total': elapsed},
    error: reason,
  );

  DocumentIntelligenceResult _partial(
    String fileName,
    int elapsed,
    String reason,
  ) => DocumentIntelligenceResult(
    status: DocumentIntelligenceStatus.partial,
    documentType: _extension(fileName) == 'pdf' ? 'pdf' : 'document',
    evidence: <String, List<String>>{
      'PDF_ANALYSIS_STATUS': <String>['PARTIAL', reason],
    },
    extractedUrls: const <String>[],
    indicators: <String>[
      reason,
      'INCOMPLETE_ANALYSIS: this is not treated as safe.',
    ],
    metadata: const DocumentMetadata(),
    timingsMs: <String, int>{'total': elapsed},
    error: reason,
  );

  static File? _fileFromReference(String reference) {
    if (reference.startsWith('content://') ||
        reference.startsWith('picker://')) {
      return null;
    }
    return reference.startsWith('file://')
        ? File.fromUri(Uri.parse(reference))
        : File(reference);
  }

  static bool _looksLikePdf(Uint8List bytes) =>
      bytes.length >= 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

  static bool _hasPdfEof(Uint8List bytes) {
    final int start = bytes.length > 4096 ? bytes.length - 4096 : 0;
    return _latin1(bytes.sublist(start)).contains('%%EOF');
  }

  static String _latin1(Uint8List bytes) =>
      String.fromCharCodes(bytes.map((int value) => value & 0xff));

  static String _extractPdfText(String source) {
    final List<String> parts = <String>[];
    final RegExp literal = RegExp(
      r'\((?:\\.|[^\\)])*\)\s*(?:Tj|TJ)',
      multiLine: true,
    );
    for (final RegExpMatch match in literal.allMatches(source)) {
      final String token = match.group(0)!;
      final int end = token.lastIndexOf(')');
      if (end > 0) parts.add(_decodeLiteral(token.substring(1, end)));
    }
    final RegExp hex = RegExp(
      r'<([0-9A-Fa-f\s]+)>\s*(?:Tj|TJ)',
      multiLine: true,
    );
    for (final RegExpMatch match in hex.allMatches(source)) {
      final String value = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
      final StringBuffer decoded = StringBuffer();
      for (int index = 0; index + 1 < value.length; index += 2) {
        decoded.writeCharCode(
          int.parse(value.substring(index, index + 2), radix: 16),
        );
      }
      parts.add(decoded.toString());
    }
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodeLiteral(String value) => value
      .replaceAll(r'\\', r'\\')
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\n');

  static String? _pdfInfoValue(String source, String key) {
    final RegExpMatch? match = RegExp(
      '/${RegExp.escape(key)}\\s*\\(([^)]{1,300})\\)',
    ).firstMatch(source);
    return match?.group(1)?.trim();
  }

  static void _addMetadataEvidence(
    List<String> output,
    DocumentMetadata metadata,
  ) {
    final Map<String, String?> values = <String, String?>{
      'TITLE': metadata.title,
      'AUTHOR': metadata.author,
      'CREATOR': metadata.creator,
      'PRODUCER': metadata.producer,
      'CREATION_DATE': metadata.creationDate,
      'MODIFICATION_DATE': metadata.modificationDate,
      'PDF_VERSION': metadata.pdfVersion,
      'PAGE_COUNT': metadata.pageCount?.toString(),
    };
    for (final MapEntry<String, String?> entry in values.entries) {
      final String? value = entry.value;
      if (value != null && value.isNotEmpty) output.add('${entry.key}: $value');
    }
    if (output.isEmpty) {
      output.add('METADATA: no standard PDF metadata was found.');
    }
  }

  static void _addTokenEvidence(
    String source,
    Map<String, List<String>> evidence,
    List<String> indicators,
  ) {
    final List<({String token, String category, String label})> tokens =
        <({String token, String category, String label})>[
          (
            token: '/JavaScript',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'JAVASCRIPT_INDICATOR',
          ),
          (
            token: '/JS',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'JAVASCRIPT_INDICATOR',
          ),
          (
            token: '/Launch',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'LAUNCH_ACTION_INDICATOR',
          ),
          (
            token: '/OpenAction',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'AUTOMATIC_ACTION_INDICATOR',
          ),
          (
            token: '/AA',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'AUTOMATIC_ACTION_INDICATOR',
          ),
          (
            token: '/EmbeddedFile',
            category: 'PDF_EMBEDDED_CONTENT',
            label: 'EMBEDDED_FILE_INDICATOR',
          ),
          (
            token: '/Filespec',
            category: 'PDF_EMBEDDED_CONTENT',
            label: 'EMBEDDED_FILE_INDICATOR',
          ),
          (
            token: '/AcroForm',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'FORM_INDICATOR',
          ),
          (
            token: '/Annot',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'ANNOTATION_INDICATOR',
          ),
          (
            token: '/URI',
            category: 'PDF_ACTIVE_CONTENT',
            label: 'EXTERNAL_REFERENCE_INDICATOR',
          ),
        ];
    final Set<String> found = <String>{};
    for (final ({String token, String category, String label}) item in tokens) {
      if (!source.contains(item.token) || !found.add(item.label)) continue;
      evidence[item.category]!.add(
        '${item.label}: ${item.token} was detected; nothing was executed.',
      );
      indicators.add('${item.label}: document contains ${item.token}.');
    }
  }

  static List<String> _extractUrls(String source) {
    final RegExp pattern = RegExp(
      r'''https?://[^\s<>()\[\]{}"']+''',
      caseSensitive: false,
    );
    final Set<String> urls = <String>{};
    for (final RegExpMatch match in pattern.allMatches(source)) {
      final String value = match.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
      if (value.length <= 2048) urls.add(value);
      if (urls.length == 50) break;
    }
    return urls.toList(growable: false);
  }

  static bool _isSupportedTextDocument(String extension, String? mimeType) =>
      const <String>{
        'txt',
        'csv',
        'md',
        'markdown',
        'json',
        'xml',
        'html',
        'htm',
        'rtf',
      }.contains(extension) ||
      (mimeType?.startsWith('text/') ?? false);

  static String _extension(String fileName) =>
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

  static Map<String, List<String>> _freezeEvidence(
    Map<String, List<String>> evidence,
  ) => Map<String, List<String>>.unmodifiable(
    evidence.map(
      (String key, List<String> value) =>
          MapEntry<String, List<String>>(key, List<String>.unmodifiable(value)),
    ),
  );
}
