import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/transfer.dart';
import 'novel_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.db});

  final AppDatabase db;

  Future<void> _createNovel(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建小说'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '书名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '简介(可选)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      await db.createNovel(titleCtrl.text.trim(), descCtrl.text.trim());
    }
  }

  Future<void> _confirmDeleteNovel(BuildContext context, Novel novel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除《${novel.title}》?'),
        content: const Text('该小说下的所有人物、地点、物品、场景都会一并删除,不可恢复。'),
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
    if (ok == true) await db.deleteNovel(novel.id);
  }

  void _toast(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _export(BuildContext context, Novel novel) async {
    try {
      final done = await NovelTransfer.exportToFile(db, novel);
      if (done && context.mounted) _toast(context, '已导出《${novel.title}》');
    } catch (e) {
      if (context.mounted) _toast(context, '导出失败：$e', error: true);
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final title = await NovelTransfer.importFromFile(db);
      if (title != null && context.mounted) {
        _toast(context, '已导入《$title》');
      }
    } on FormatException catch (e) {
      if (context.mounted) _toast(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('墨澜'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: '导入小说',
            onPressed: () => _import(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: StreamBuilder<List<Novel>>(
        stream: db.watchNovels(),
        builder: (context, snapshot) {
          final novels = snapshot.data ?? const [];
          if (novels.isEmpty) {
            return const Center(
              child: Text('还没有小说,点右下角开始创作', style: TextStyle(fontSize: 16)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: novels.length,
            itemBuilder: (context, i) {
              final novel = novels[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(novel.title),
                  subtitle: novel.description.isEmpty
                      ? null
                      : Text(novel.description,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'export') _export(context, novel);
                      if (v == 'delete') _confirmDeleteNovel(context, novel);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'export', child: Text('导出')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NovelPage(db: db, novel: novel))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNovel(context),
        icon: const Icon(Icons.add),
        label: const Text('新建小说'),
      ),
    );
  }
}
