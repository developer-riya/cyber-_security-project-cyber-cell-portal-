import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum ThreatIntelligenceTransportError {
  timeout,
  network,
  responseTooLarge,
  insecureEndpoint,
}

class ThreatIntelligenceTransportException implements Exception {
  const ThreatIntelligenceTransportException(this.error);

  final ThreatIntelligenceTransportError error;
}

class ThreatIntelligenceHttpRequest {
  const ThreatIntelligenceHttpRequest({
    required this.endpoint,
    required this.body,
    this.headers = const <String, String>{},
  });

  final Uri endpoint;
  final List<int> body;
  final Map<String, String> headers;
}

class ThreatIntelligenceHttpResponse {
  const ThreatIntelligenceHttpResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Uint8List bodyBytes;
  final Map<String, String> headers;
}

abstract interface class ThreatIntelligenceHttpTransport {
  Future<ThreatIntelligenceHttpResponse> post(
    ThreatIntelligenceHttpRequest request, {
    required Duration connectionTimeout,
    required Duration responseTimeout,
    required int maxResponseBytes,
  });
}

/// Small cross-platform REST transport. It accepts only HTTPS endpoints and
/// bounds both time-to-headers and streamed response bytes.
class BoundedThreatIntelligenceHttpTransport
    implements ThreatIntelligenceHttpTransport {
  BoundedThreatIntelligenceHttpTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<ThreatIntelligenceHttpResponse> post(
    ThreatIntelligenceHttpRequest request, {
    required Duration connectionTimeout,
    required Duration responseTimeout,
    required int maxResponseBytes,
  }) async {
    if (request.endpoint.scheme != 'https' || request.endpoint.host.isEmpty) {
      throw const ThreatIntelligenceTransportException(
        ThreatIntelligenceTransportError.insecureEndpoint,
      );
    }
    final http.Request httpRequest = http.Request('POST', request.endpoint)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.body;
    try {
      final http.StreamedResponse response = await _client
          .send(httpRequest)
          .timeout(connectionTimeout);
      final BytesBuilder bytes = BytesBuilder(copy: false);
      await response.stream.timeout(responseTimeout).forEach((List<int> chunk) {
        if (bytes.length + chunk.length > maxResponseBytes) {
          throw const ThreatIntelligenceTransportException(
            ThreatIntelligenceTransportError.responseTooLarge,
          );
        }
        bytes.add(chunk);
      });
      return ThreatIntelligenceHttpResponse(
        statusCode: response.statusCode,
        bodyBytes: bytes.takeBytes(),
        headers: Map<String, String>.unmodifiable(response.headers),
      );
    } on ThreatIntelligenceTransportException {
      rethrow;
    } on TimeoutException {
      throw const ThreatIntelligenceTransportException(
        ThreatIntelligenceTransportError.timeout,
      );
    } catch (_) {
      throw const ThreatIntelligenceTransportException(
        ThreatIntelligenceTransportError.network,
      );
    }
  }
}
