/// Reading-domain models kept separate from Molan's writing chapters.
class ReaderBook {
  const ReaderBook({
    required this.id,
    required this.title,
    this.author = '',
    this.sourceId = 'local',
    this.canonicalUrl,
  });
  final String id;
  final String title;
  final String author;
  final String sourceId;
  final String? canonicalUrl;
}

class ReaderChapter {
  const ReaderChapter({
    required this.bookId,
    required this.index,
    required this.title,
    this.originalHtml = '',
    this.translatedHtml = '',
  });
  final String bookId;
  final int index;
  final String title;
  final String originalHtml;
  final String translatedHtml;
}
