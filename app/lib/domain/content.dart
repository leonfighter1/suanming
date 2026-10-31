import 'models.dart' show Json;

/// 内容管理 (S29): what staff changed of the app's texts (by message key) and images (by key: banner, logo), in the
/// app's language. Only the changes: the app has its own for everything else.
class ContentView {
  const ContentView({this.texts = const {}, this.images = const {}});

  factory ContentView.fromJson(Json j) => ContentView(
        texts: (j['texts'] as Map? ?? const {}).cast<String, String>(),
        images: (j['images'] as Map? ?? const {}).cast<String, String>(),
      );

  /// Nothing changed: the app's own throughout.
  static const none = ContentView();

  final Map<String, String> texts;

  /// Each image's address on the server, relative to it.
  final Map<String, String> images;
}
