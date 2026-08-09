import 'package:flutter/material.dart';

import '../data/db.dart';
import 'chapter_page.dart';

/// 新建/重命名章节对话框
Future<void> showChapterDialog(BuildContext context, AppDatabase db, Novel novel,
    {Chapter? chapter}) async {
  final ctrl = TextEditingController(text: chapter?.title ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(chapter == null ? '新建章节' : '重命名章节'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
            labelText: '章节标题',
            hintText: '第一章 雪夜来客',
            border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(chapter == null ? '创建' : '保存')),
      ],
    ),
  );
  final title = ctrl.text.trim();
  if (ok != true || title.isEmpty) return;
  if (chapter == null) {
    await db.createChapter(novel.id, title);
  } else {
    await db.renameChapter(chapter.id, title);
  }
}

/// 写作区:章节列表(内嵌视图,无 Scaffold)
class ChaptersView extends StatelessWidget {
  const ChaptersView({super.key, required this.db, required this.novel});

  final AppDatabase db;
  final Novel novel;

  Future<void> _confirmDelete(BuildContext context, Chapter chapter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除《${chapter.title}》?'),
        content: const Text('本章的全部事件与内容会一并删除,不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await db.deleteChapter(chapter.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Chapter>>(
      stream: db.watchChapters(novel.id),
      builder: (context, snapshot) {
        final chapters = snapshot.data ?? const [];
        if (chapters.isEmpty) {
          return const Center(child: Text('还没有章节,点右下角开始写作'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chapters.length,
          itemBuilder: (context, i) {
            final c = chapters[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(c.title),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') {
                      showChapterDialog(context, db, novel, chapter: c);
                    }
                    if (v == 'delete') _confirmDelete(context, c);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChapterPage(db: db, novel: novel, chapter: c)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
