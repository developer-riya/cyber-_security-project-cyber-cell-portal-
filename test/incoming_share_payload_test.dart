import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes shared text links and file metadata', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'share-1',
        'receivedAt': 1,
        'mimeType': 'text/plain',
        'text': 'Check https://example.test/account before opening',
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/invoice.pdf',
            'mimeType': 'application/pdf',
            'contentType': 'pdf',
            'fileName': 'invoice.pdf',
            'sizeBytes': 2048,
            'isAccessible': true,
          },
        ],
      },
    );

    expect(payload.primaryType, IncomingShareContentType.link);
    expect(payload.urls, <String>['https://example.test/account']);
    expect(
      payload.attachments.single.contentType,
      IncomingShareContentType.pdf,
    );
    expect(payload.attachments.single.displayName, 'invoice.pdf');
  });

  test('treats unknown files as unsupported instead of executable input', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'share-2',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/archive.bin',
            'mimeType': 'application/x-custom-binary',
            'contentType': 'unsupported',
            'fileName': 'archive.bin',
            'isAccessible': true,
          },
        ],
      },
    );

    expect(payload.primaryType, IncomingShareContentType.unsupported);
  });

  test('keeps multiple shared attachments as one related payload', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'share-multiple',
        'receivedAt': 1,
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/first.pdf',
            'mimeType': 'application/pdf',
            'fileName': 'first.pdf',
            'isAccessible': true,
          },
          <Object?, Object?>{
            'uri': 'content://example/second.png',
            'mimeType': 'image/png',
            'fileName': 'second.png',
            'isAccessible': true,
          },
        ],
      },
    );

    expect(payload.isMultiple, isTrue);
    expect(payload.attachments, hasLength(2));
    expect(
      payload.attachments.last.contentType,
      IncomingShareContentType.image,
    );
  });

  test('classifies APKs and preserves the optional source application', () {
    final IncomingSharePayload payload = IncomingSharePayload.fromPlatformMap(
      <Object?, Object?>{
        'id': 'share-apk',
        'receivedAt': 1,
        'sourceApplication': 'com.android.chrome',
        'items': <Object?>[
          <Object?, Object?>{
            'uri': 'content://example/update.apk',
            'mimeType': 'application/vnd.android.package-archive',
            'fileName': 'update.apk',
            'isAccessible': true,
          },
        ],
      },
    );

    expect(payload.primaryType, IncomingShareContentType.apk);
    expect(payload.sourceApplication, 'com.android.chrome');
    expect(payload.displayTitle, 'Android application received');
  });

  test('normalizes a manually selected PDF reference', () {
    final IncomingShareAttachment attachment =
        IncomingShareAttachment.fromFileReference(
          reference: 'picker://invoice.pdf',
          fileName: 'invoice.pdf',
          sizeBytes: 1024,
        );
    final IncomingSharePayload payload = IncomingSharePayload.fromManualFiles(
      <IncomingShareAttachment>[attachment],
    );

    expect(payload.primaryType, IncomingShareContentType.pdf);
    expect(payload.sourceApplication, 'Cyber Uday file picker');
    expect(payload.attachments.single.sizeBytes, 1024);
  });
}
