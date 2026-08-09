import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'db.dart';
import 'save_file_stub.dart' if (dart.library.io) 'save_file_io.dart';

/// 小说导出/导入(JSON 文件)
class NovelTransfer {
  static const _formatVersion = 1;

  static Future<String> exportJson(AppDatabase db, Novel novel) async {
    final entries = await db.allEntriesOf(novel.id);
    final rels = await db.relationsOfNovel(novel.id);
    final links = await db.linksOfNovel(novel.id);
    final chapterRows = await db.watchChapters(novel.id).first;
    final indexOf = {
      for (var i = 0; i < entries.length; i++) entries[i].id: i
    };
    final chapterData = [
      for (final c in chapterRows)
        {
          'title': c.title,
          'events': [
            for (final e in await db.eventsOf(c.id))
              {'outline': e.outline, 'content': e.content}
          ],
        }
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'molan_export': _formatVersion,
      'novel': {'title': novel.title, 'description': novel.description},
      'entries': [
        for (final e in entries)
          {
            'kind': e.kind,
            'name': e.name,
            'content': e.content,
            if (e.parentId != null && indexOf.containsKey(e.parentId))
              'parent': indexOf[e.parentId],
          }
      ],
      'relations': [
        for (final r in rels)
          if (indexOf.containsKey(r.fromEntryId) &&
              indexOf.containsKey(r.toEntryId))
            {
              'from': indexOf[r.fromEntryId],
              'to': indexOf[r.toEntryId],
              'label': r.label,
            }
      ],
      'links': [
        for (final l in links)
          if (indexOf.containsKey(l.fromEntryId) &&
              indexOf.containsKey(l.toEntryId))
            {'from': indexOf[l.fromEntryId], 'to': indexOf[l.toEntryId]}
      ],
      'chapters': chapterData,
    });
  }

  /// 导出为文件;返回是否完成(用户取消返回 false)
  static Future<bool> exportToFile(AppDatabase db, Novel novel) async {
    final bytes =
        Uint8List.fromList(utf8.encode(await exportJson(db, novel)));
    final path = await FilePicker.platform.saveFile(
      fileName: 'molan-${novel.title}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path == null) return false;
    await maybeWriteFile(path, bytes);
    return true;
  }

  /// 从文件导入,返回导入的小说标题;用户取消返回 null
  static Future<String?> importFromFile(AppDatabase db) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = res?.files.single.bytes;
    if (bytes == null) return null;
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('文件不是有效的 JSON');
    }
    if (data is! Map || data['molan_export'] == null) {
      throw const FormatException('这不是墨澜导出的文件');
    }
    final novel = data['novel'] as Map? ?? {};
    final title = (novel['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) throw const FormatException('文件缺少小说标题');
    final entryRows = [
      for (final e in (data['entries'] as List? ?? []))
        if (e is Map && (e['name'] as String?)?.isNotEmpty == true)
          (
            kind: e['kind'] as String? ?? 'character',
            name: e['name'] as String,
            content: e['content'] as String? ?? '',
            parent: e['parent'] is int ? e['parent'] as int : null,
          )
    ];
    final relRows = [
      for (final r in (data['relations'] as List? ?? []))
        if (r is Map && r['from'] is int && r['to'] is int)
          (
            from: r['from'] as int,
            to: r['to'] as int,
            label: r['label'] as String? ?? '',
          )
    ];
    final linkRows = [
      for (final l in (data['links'] as List? ?? []))
        if (l is Map && l['from'] is int && l['to'] is int)
          (from: l['from'] as int, to: l['to'] as int)
    ];
    final chapterRows = [
      for (final c in (data['chapters'] as List? ?? []))
        if (c is Map && (c['title'] as String?)?.isNotEmpty == true)
          (
            title: c['title'] as String,
            events: [
              for (final e in (c['events'] as List? ?? []))
                if (e is Map)
                  (
                    outline: e['outline'] as String? ?? '',
                    content: e['content'] as String? ?? '',
                  )
            ],
          )
    ];
    await db.importNovel(title, novel['description'] as String? ?? '',
        entryRows, relRows, linkRows, chapterRows);
    return title;
  }
}
