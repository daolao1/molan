import 'package:flutter/material.dart';

import '../data/db.dart';

/// 阅读模式:章节目录 + 沉浸正文
class ReadingView extends StatefulWidget {
  const ReadingView({super.key, required this.db, required this.novel});

  final AppDatabase db;
  final Novel novel;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<ReadingView> {
  int? _chapterId;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _selectChapter(int id) {
    setState(() => _chapterId = id);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Chapter>>(
      stream: widget.db.watchChapters(widget.novel.id),
      builder: (context, snapshot) {
        final chapters = snapshot.data ?? const [];
        if (chapters.isEmpty) {
          return const Center(child: Text('还没有章节,去写作里创建吧'));
        }
        final current = chapters.firstWhere((c) => c.id == _chapterId,
            orElse: () => chapters.first);
        final index = chapters.indexWhere((c) => c.id == current.id);
        // 窄屏:目录改为顶部下拉,正文占满
        final narrow = MediaQuery.sizeOf(context).width < 600;
        final body = _chapterBody(context, chapters, current, index);
        if (narrow) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<int>(
                  initialValue: current.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: '章节',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: [
                    for (final c in chapters)
                      DropdownMenuItem(
                          value: c.id,
                          child:
                              Text(c.title, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => v == null ? null : _selectChapter(v),
                ),
              ),
              Expanded(child: body),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 168,
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final c = chapters[i];
                  return ListTile(
                    dense: true,
                    selected: c.id == current.id,
                    title: Text(c.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectChapter(c.id),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _chapterBody(BuildContext context, List<Chapter> chapters,
      Chapter current, int index) {
    return StreamBuilder<List<ChapterEvent>>(
      stream: widget.db.watchEvents(current.id),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const [];
        final text = [
          for (final e in events)
            if (e.content.trim().isNotEmpty) e.content.trim()
        ].join('\n\n');
        return SingleChildScrollView(
          controller: _scrollCtrl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    if (text.isEmpty)
                      Text('(本章还没有正文)',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline))
                    else
                      SelectableText(text,
                          style: const TextStyle(fontSize: 17, height: 1.9)),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        if (index > 0)
                          Flexible(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _selectChapter(chapters[index - 1].id),
                              icon: const Icon(Icons.chevron_left),
                              label: Text(chapters[index - 1].title,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        const Spacer(),
                        if (index < chapters.length - 1)
                          Flexible(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _selectChapter(chapters[index + 1].id),
                              icon: const Icon(Icons.chevron_right),
                              label: Text(chapters[index + 1].title,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
