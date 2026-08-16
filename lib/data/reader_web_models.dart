class WebBookChapter {
  const WebBookChapter({
    required this.title,
    required this.url,
    this.html,
    this.groupTitle,
  });
  final String title;
  final String url;
  final String? html;
  final String? groupTitle;
  WebBookChapter copyWith({String? html}) => WebBookChapter(
    title: title,
    url: url,
    html: html ?? this.html,
    groupTitle: groupTitle,
  );
}

class CachedWebBook {
  const CachedWebBook({
    required this.canonicalUrl,
    required this.title,
    this.author = '',
    this.summary = '',
    this.coverUrl,
    this.tags = const [],
    this.chapters = const [],
  });
  final String canonicalUrl;
  final String title;
  final String author;
  final String summary;
  final String? coverUrl;
  final List<String> tags;
  final List<WebBookChapter> chapters;
}

class DiscoveryItem {
  const DiscoveryItem({
    required this.id,
    required this.detailUrl,
    required this.title,
    this.author,
    this.coverUrl,
    this.summary,
    this.tags = const [],
    this.status,
  });
  final String id;
  final String detailUrl;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? summary;
  final List<String> tags;
  final String? status;
}

class DiscoveryPage {
  const DiscoveryPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });
  final List<DiscoveryItem> items;
  final int page;
  final bool hasMore;
}

abstract interface class WebSource {
  String get id;
  String get displayName;
  bool matches(Uri url);
  String canonicalize(String input);
  Future<CachedWebBook> fetchIndex(String canonicalUrl);
  Future<WebBookChapter> fetchChapter(
    String canonicalUrl,
    WebBookChapter chapter,
  );
}
