import 'db.dart';
import 'entry_fields.dart';

/// 供 LLM function calling 使用的小说设定检索工具
const novelToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'get_entry_detail',
      'description': '获取某个设定条目的完整详细内容,含双向关联(人物关系、场景归属等)',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '条目名称,须与清单中的名称一致'}
        },
        'required': ['name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_entries',
      'description': '列出本小说的设定条目名称,可按类型过滤',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore'],
            'description': '条目类型;省略则返回全部类型',
          }
        },
      },
    },
  },
];

/// 执行工具调用,返回给模型的文本结果
class NovelToolExecutor {
  NovelToolExecutor(this.db, this.novelId);

  final AppDatabase db;
  final int novelId;

  Future<String> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'get_entry_detail':
        return _entryDetail(args['name'] as String? ?? '');
      case 'list_entries':
        return _listEntries(args['kind'] as String?);
      default:
        return '未知工具:$name';
    }
  }

  Future<String> _entryDetail(String name) async {
    final all = await db.allEntriesOf(novelId);
    final matches = [
      for (final e in all)
        if (e.name == name.trim()) e
    ];
    if (matches.isEmpty) return '未找到名为「$name」的条目';
    final e = matches.first;
    final kind = EntryKind.values.byName(e.kind);
    final data = parseEntryContent(e.content);
    final buf = StringBuffer('${kind.label}「${e.name}」:\n');
    final links = await db.linksFrom(e.id);
    if (links.isNotEmpty) {
      buf.writeln('关联(本卡发起):');
      for (final l in links) {
        final to = all.where((x) => x.id == l.toEntryId).firstOrNull;
        if (to != null) {
          buf.writeln(
              '- → ${to.name}${l.label.isEmpty ? '' : ':${l.label}'}');
        }
      }
    }
    final incoming = await db.linksTo(e.id);
    if (incoming.isNotEmpty) {
      buf.writeln('被关联:');
      for (final l in incoming) {
        final from = all.where((x) => x.id == l.fromEntryId).firstOrNull;
        if (from != null) {
          buf.writeln(
              '- ← ${from.name}${l.label.isEmpty ? '' : ':${l.label}'}');
        }
      }
    }
    for (final f in entryFieldsFor(kind)) {
      final v = data[f.key]?.trim() ?? '';
      if (v.isNotEmpty) buf.writeln('${f.label}:$v');
    }
    for (final x in extensionFields(kind, data).entries) {
      if (x.value.trim().isNotEmpty) buf.writeln('${x.key}:${x.value.trim()}');
    }
    return buf.toString().trimRight();
  }

  Future<String> _listEntries(String? kindName) async {
    final all = await db.allEntriesOf(novelId);
    final kinds = kindName == null
        ? EntryKind.values
        : [EntryKind.values.byName(kindName)];
    final buf = StringBuffer();
    for (final kind in kinds) {
      final names = [
        for (final e in all)
          if (e.kind == kind.name) e.name
      ];
      if (names.isNotEmpty) buf.writeln('${kind.label}:${names.join('、')}');
    }
    return buf.isEmpty ? '(暂无条目)' : buf.toString().trimRight();
  }
}
