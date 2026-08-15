import 'package:flutter/material.dart';
import '../data/chapter_translator.dart';
import '../data/db.dart';
import '../data/settings.dart';

class ReaderBookPage extends StatefulWidget {
  const ReaderBookPage({super.key, required this.db, required this.bookId});
  final AppDatabase db;
  final int bookId;
  @override
  State<ReaderBookPage> createState() => _ReaderBookPageState();
}

class _ReaderBookPageState extends State<ReaderBookPage> {
  final _scroll = ScrollController();
  int? _chapterId;
  bool _busy = false;
  double _progress = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_chapterId != null &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent > 0) {
        final fraction = (_scroll.offset / _scroll.position.maxScrollExtent)
            .clamp(0.0, 1.0);
        widget.db.saveReaderProgress(
          bookId: widget.bookId,
          chapterId: _chapterId,
          fraction: fraction,
        );
      }
    });
    widget.db.readerProgressFor(widget.bookId).then((p) {
      if (!mounted || p == null) return;
      setState(() => _chapterId = p.chapterId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients)
          _scroll.jumpTo(_scroll.position.maxScrollExtent * p.scrollFraction);
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _translate(ReaderChapter c) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await SettingsStore.loadFor(LlmPurpose.writing);
      final result = await ChapterTranslator().translate(
        settings: s,
        targetLanguage: '中文',
        chapterTitle: c.title,
        chapterHtml: c.originalHtml,
        onProgress: (a, b) {
          if (mounted) setState(() => _progress = a / b);
        },
      );
      await widget.db.updateReaderTranslation(
        c.id,
        html: result.html,
        state: 'done',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('翻译失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReaderBook?>(
    future: widget.db.readerBookById(widget.bookId),
    builder: (context, bookSnap) {
      final book = bookSnap.data;
      if (book == null)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return FutureBuilder<List<ReaderChapter>>(
        future: widget.db.readerChaptersOf(widget.bookId),
        builder: (context, snap) {
          final chapters = snap.data ?? const <ReaderChapter>[];
          if (chapters.isEmpty)
            return Scaffold(
              appBar: AppBar(title: Text(book.title)),
              body: const Center(child: Text('没有章节')),
            );
          final current = chapters.firstWhere(
            (x) => x.id == _chapterId,
            orElse: () => chapters.first,
          );
          final index = chapters.indexOf(current);
          final html = current.translatedHtml.isNotEmpty
              ? current.translatedHtml
              : current.originalHtml;
          return Scaffold(
            appBar: AppBar(
              title: Text(book.title),
              actions: [
                IconButton(
                  onPressed: _busy ? null : () => _translate(current),
                  icon: const Icon(Icons.translate),
                  tooltip: '翻译本章',
                ),
              ],
            ),
            body: Column(
              children: [
                if (_busy) LinearProgressIndicator(value: _progress),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 190,
                        child: ListView(
                          children: [
                            for (final c in chapters)
                              ListTile(
                                selected: c.id == current.id,
                                title: Text(
                                  c.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => setState(() => _chapterId = c.id),
                              ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(24),
                          child: SelectableText(
                            _plain(html),
                            style: const TextStyle(fontSize: 18, height: 1.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: index > 0
                      ? () =>
                            setState(() => _chapterId = chapters[index - 1].id)
                      : null,
                  child: const Text('上一章'),
                ),
                Text('${index + 1}/${chapters.length}'),
                TextButton(
                  onPressed: index + 1 < chapters.length
                      ? () =>
                            setState(() => _chapterId = chapters[index + 1].id)
                      : null,
                  child: const Text('下一章'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  String _plain(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
