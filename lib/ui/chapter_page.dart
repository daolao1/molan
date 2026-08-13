import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';
import 'event_edit_page.dart';

/// 章节页:小节流
class ChapterPage extends StatelessWidget {
  const ChapterPage(
      {super.key,
      required this.db,
      required this.novel,
      required this.chapter});

  final AppDatabase db;
  final Novel novel;
  final Chapter chapter;

  void _openEvent(BuildContext context,
      {ChapterEvent? event, required List<ChapterEvent> all}) {
    final idx = event == null
        ? all.length
        : all.indexWhere((e) => e.id == event.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditPage(
          db: db,
          novel: novel,
          chapter: chapter,
          event: event,
          priorEvents: all.sublist(0, idx < 0 ? all.length : idx),
          followingEvents:
              idx < 0 || idx + 1 > all.length ? const [] : all.sublist(idx + (event == null ? 0 : 1)),
        ),
      ),
    );
  }

  /// 章节全文 = 各小节内容拼接;章节大纲 = 各小节大纲拼接
  Future<void> _showFullText(BuildContext context,
      {required bool outline}) async {
    final events = await db.eventsOf(chapter.id);
    final text = [
      for (final (i, e) in events.indexed)
        if ((outline ? e.outline : e.content).trim().isNotEmpty)
          '${e.name.trim().isEmpty ? '小节 ${i + 1}' : e.name.trim()}\n'
          '${(outline ? e.outline : e.content).trim()}'
    ].where((s) => s.isNotEmpty).join('\n\n');
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(outline ? '章节大纲' : '章节全文(${text.length} 字)'),
        content: SizedBox(
          width: double.maxFinite,
          child: text.isEmpty
              ? const Text('(暂无内容)')
              : SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: '章节大纲',
            onPressed: () => _showFullText(context, outline: true),
          ),
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: '章节全文',
            onPressed: () => _showFullText(context, outline: false),
          ),
        ],
      ),
      body: StreamBuilder<List<ChapterEvent>>(
        stream: db.watchEvents(chapter.id),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return const Center(
                child: Text('还没有小节,点右下角添加\n每个小节 = 名称 + 大纲 + 正文',
                    textAlign: TextAlign.center));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              final hasContent = e.content.trim().isNotEmpty;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
                  ),
                  title: Text(e.name.trim().isEmpty ? '小节 ${i + 1}' : e.name),
                  subtitle: Text(
                    '${e.outline.trim().isEmpty ? '未写大纲' : e.outline.trim()} · '
                    '${hasContent ? '${e.content.trim().length} 字' : '正文未生成'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: hasContent
                            ? null
                            : Theme.of(context).colorScheme.error),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') await db.deleteEvent(e.id);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => _openEvent(context, event: e, all: events),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final events = await db.eventsOf(chapter.id);
          if (context.mounted) _openEvent(context, all: events);
        },
        icon: const Icon(Icons.add),
        label: const Text('添加小节'),
      ),
    );
  }
}
