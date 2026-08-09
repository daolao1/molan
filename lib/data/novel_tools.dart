import 'db.dart';
import 'entry_fields.dart';

/// 供 LLM function calling 使用的小说设定检索工具
const novelToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'get_entry_detail',
      'description': '获取某个设定条目(人物/地点/物品/场景)的完整详细内容',
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
  {
    'type': 'function',
    'function': {
      'name': 'get_relations',
      'description': '查询人物关系;给定人物名则只返回与其相关的关系,省略则返回全部',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '人物名称,可省略'}
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
      case 'get_relations':
        return _relations(args['name'] as String?);
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
    if (e.parentId != null) {
      final parent = all.where((x) => x.id == e.parentId).firstOrNull;
      if (parent != null) buf.writeln('所属地点:${parent.name}');
    }
    for (final f in entryFieldsFor(kind)) {
      final v = data[f.key]?.trim() ?? '';
      if (v.isNotEmpty) buf.writeln('${f.label}:$v');
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

  Future<String> _relations(String? name) async {
    final all = await db.allEntriesOf(novelId);
    final nameOf = {for (final e in all) e.id: e.name};
    final rels = await db.relationsOfNovel(novelId);
    final lines = [
      for (final r in rels)
        if (name == null ||
            nameOf[r.fromEntryId] == name ||
            nameOf[r.toEntryId] == name)
          '${nameOf[r.fromEntryId]} →${r.label}→ ${nameOf[r.toEntryId]}'
    ];
    return lines.isEmpty ? '(无相关关系)' : lines.join('\n');
  }
}
