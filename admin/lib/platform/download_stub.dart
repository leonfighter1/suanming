import 'dart:typed_data';

/// Not on the web: nothing to download into (false).
Future<bool> downloadFile(Uint8List bytes, String name, String mime) async => false;
