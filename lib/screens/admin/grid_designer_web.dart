import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadFileWeb(String content, String fileName) {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

void saveFileDesktop(String path, String content) {}
