import 'dart:io';

import 'package:crypto/crypto.dart';

Future<String?> sha256ForReference(
  String reference, {
  required int maxBytes,
}) async {
  if (reference.startsWith('content://') || reference.startsWith('picker://')) {
    return null;
  }
  final File file = reference.startsWith('file://')
      ? File.fromUri(Uri.parse(reference))
      : File(reference);
  if (!await file.exists()) return null;
  final int size = await file.length();
  if (size < 0 || size > maxBytes) return null;
  final List<int> bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}
