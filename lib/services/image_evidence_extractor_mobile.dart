import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'image_evidence_models.dart';
import 'security_pipeline_config.dart';

/// Android/iOS on-device OCR and QR extraction for quarantined file copies.
/// It does not render images, open URL payloads, or communicate with a cloud
/// service. ML Kit receives only the local temporary file path.
class LocalImageEvidenceExtractor implements ImageEvidenceExtractor {
  const LocalImageEvidenceExtractor({
    this.config = const SecurityPipelineConfig(),
  });

  final SecurityPipelineConfig config;

  @override
  Future<ImageEvidenceExtraction> extract(String contentReference) async {
    final Stopwatch total = Stopwatch()..start();
    final File file = File.fromUri(Uri.parse(contentReference));
    final _ImagePreflight preflight;
    try {
      preflight = await _inspect(file);
    } on _ImagePreflightException catch (error) {
      return ImageEvidenceExtraction(
        status: ImageExtractionStatus.failed,
        ocrText: null,
        qrPayloads: const <String>[],
        decodeDurationMs: total.elapsedMilliseconds,
        ocrDurationMs: 0,
        qrDurationMs: 0,
        messages: <String>[error.message],
      );
    } catch (_) {
      return ImageEvidenceExtraction(
        status: ImageExtractionStatus.failed,
        ocrText: null,
        qrPayloads: const <String>[],
        decodeDurationMs: total.elapsedMilliseconds,
        ocrDurationMs: 0,
        qrDurationMs: 0,
        messages: const <String>[
          'Image preflight failed; no OCR or QR result was assigned.',
        ],
      );
    }

    final InputImage input = InputImage.fromFilePath(file.path);
    final List<String> messages = <String>[];
    String? text;
    List<String> qrPayloads = const <String>[];
    int ocrMs = 0;
    int qrMs = 0;
    bool ocrSucceeded = false;
    bool qrSucceeded = false;

    final Stopwatch ocrWatch = Stopwatch()..start();
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final RecognizedText recognized = await recognizer.processImage(input);
      text = recognized.text.trim().isEmpty ? null : recognized.text.trim();
      ocrSucceeded = true;
      if (text == null) {
        messages.add('OCR completed but no readable text was found.');
      }
    } catch (_) {
      messages.add('OCR_UNAVAILABLE: local text extraction did not complete.');
    } finally {
      ocrMs = ocrWatch.elapsedMilliseconds;
      await recognizer.close();
    }

    final Stopwatch qrWatch = Stopwatch()..start();
    final BarcodeScanner scanner = BarcodeScanner(
      formats: <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    try {
      final List<Barcode> codes = await scanner.processImage(input);
      qrPayloads = codes
          .map((code) => code.rawValue?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      qrSucceeded = true;
      if (qrPayloads.isEmpty) messages.add('No QR code payload was detected.');
    } catch (_) {
      messages.add('QR_UNAVAILABLE: local QR extraction did not complete.');
    } finally {
      qrMs = qrWatch.elapsedMilliseconds;
      await scanner.close();
    }

    return ImageEvidenceExtraction(
      status: ocrSucceeded && qrSucceeded
          ? ImageExtractionStatus.complete
          : (ocrSucceeded || qrSucceeded
                ? ImageExtractionStatus.partial
                : ImageExtractionStatus.unavailable),
      ocrText: text,
      qrPayloads: qrPayloads,
      decodeDurationMs: total.elapsedMilliseconds - ocrMs - qrMs,
      ocrDurationMs: ocrMs,
      qrDurationMs: qrMs,
      messages: List<String>.unmodifiable(messages),
      width: preflight.width,
      height: preflight.height,
    );
  }

  Future<_ImagePreflight> _inspect(File file) async {
    if (!await file.exists()) {
      throw const _ImagePreflightException(
        'The quarantined image is unavailable.',
      );
    }
    final int size = await file.length();
    if (size <= 0 || size > config.maxFileSizeBytes) {
      throw const _ImagePreflightException(
        'The image exceeds the configured safe size limit.',
      );
    }
    final Uint8List header = Uint8List.fromList(
      await file
          .openRead(0, size < 65536 ? size : 65536)
          .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk)),
    );
    final _ImagePreflight? dimensions = _dimensions(header);
    if (dimensions == null) {
      throw const _ImagePreflightException(
        'The image is corrupt or uses an unsupported image structure.',
      );
    }
    if (dimensions.width > config.maxImageDimension ||
        dimensions.height > config.maxImageDimension ||
        dimensions.width * dimensions.height > config.maxImagePixels) {
      throw const _ImagePreflightException(
        'The image dimensions exceed the configured safe processing limit.',
      );
    }
    return dimensions;
  }
}

class _ImagePreflight {
  const _ImagePreflight(this.width, this.height);
  final int width;
  final int height;
}

class _ImagePreflightException implements Exception {
  const _ImagePreflightException(this.message);
  final String message;
}

_ImagePreflight? _dimensions(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return _ImagePreflight(_u32(bytes, 16), _u32(bytes, 20));
  }
  if (bytes.length >= 10 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return _ImagePreflight(_u16(bytes, 6), _u16(bytes, 8));
  }
  if (bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    int cursor = 2;
    while (cursor + 9 < bytes.length) {
      if (bytes[cursor] != 0xff) return null;
      final int marker = bytes[cursor + 1];
      final int length = _u16(bytes, cursor + 2);
      if (length < 2 || cursor + 2 + length > bytes.length) return null;
      if (<int>{
        0xc0,
        0xc1,
        0xc2,
        0xc3,
        0xc5,
        0xc6,
        0xc7,
        0xc9,
        0xca,
        0xcb,
        0xcd,
        0xce,
        0xcf,
      }.contains(marker)) {
        return _ImagePreflight(
          _u16(bytes, cursor + 7),
          _u16(bytes, cursor + 5),
        );
      }
      cursor += 2 + length;
    }
  }
  return null;
}

int _u16(Uint8List bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];
int _u32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
