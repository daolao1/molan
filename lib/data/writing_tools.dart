import 'db.dart';
import 'entry_fields.dart';
import 'novel_tools.dart';

/// 写作 agent 的正文编辑工具(类编程 agent 的 read/write 范式)
const writingToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'read_content',
      'description': '读取当前事件正文全文,每行带行号前缀"N| ";修改前必须先读,replace_text 的原文不含行号前缀',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'replace_text',
      'description': '精确替换正文中的一段文字;old_text 必须与正文某处逐字一致且全文唯一',
      'parameters': {
        'type': 'object',
        'properties': {
          'old_text': {'type': 'string', 'description': '要被替换的原文片段(逐字)'},
          'new_text': {'type': 'string', 'description': '替换后的新文字'},
        },
        'required': ['old_text', 'new_text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'append_text',
      'description': '在正文结尾追加内容(续写)',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '要追加的内容'}
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_content',
      'description': '整体重写正文;仅当作者明确要求推翻重写时使用',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '新的正文全文'}
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'read_outline',
      'description': '读取当前事件的大纲',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_outline',
      'description': '更新当前事件的大纲(情节变化后同步,或按作者要求调整)',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '新的大纲文本'}
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'upsert_entry',
      'description': '新增或增量更新一张设定卡(人物/地点/物品/场景/设定):同名则合并字段,不存在则创建;写作中产生的新设定、人物状态变化及时记录',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore'],
          },
          'name': {'type': 'string', 'description': '条目名称'},
          'fields': {
            'type': 'object',
            'description': '字段内容;更新时只给需修改的字段',
          },
        },
        'required': ['kind', 'name', 'fields'],
      },
    },
  },
];

/// 执行正文编辑工具;设定检索类工具转发给 [NovelToolExecutor]
class WritingToolExecutor {
  WritingToolExecutor({
    required this.readContent,
    required this.writeContent,
    required this.readOutline,
    required this.writeOutline,
    required this.db,
    required this.novelId,
    required this.lookup,
  });

  /// 实时读取正文(编辑框内容)
  final String Function() readContent;

  /// 写回正文(编辑框内容)
  final void Function(String) writeContent;

  final String Function() readOutline;
  final void Function(String) writeOutline;
  final AppDatabase db;
  final int novelId;
  final NovelToolExecutor lookup;

  Future<String> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'read_content':
        final c = readContent();
        if (c.trim().isEmpty) return '(正文目前为空)';
        final lines = c.split('\n');
        return [
          for (var i = 0; i < lines.length; i++) '${i + 1}| ${lines[i]}'
        ].join('\n');
      case 'replace_text':
        final oldText = args['old_text'] as String? ?? '';
        final newText = args['new_text'] as String? ?? '';
        if (oldText.isEmpty) return '失败:old_text 为空';
        final content = readContent();
        final count = oldText.allMatches(content).length;
        if (count == 0) {
          return '失败:正文中未找到该片段,请先 read_content 核对原文';
        }
        if (count > 1) {
          return '失败:该片段在正文中出现 $count 处,请提供更长的唯一片段';
        }
        writeContent(content.replaceFirst(oldText, newText));
        return '已替换';
      case 'append_text':
        final text = args['text'] as String? ?? '';
        if (text.isEmpty) return '失败:text 为空';
        final content = readContent();
        writeContent(
            content.trim().isEmpty ? text : '${content.trimRight()}\n\n$text');
        return '已追加';
      case 'set_content':
        writeContent(args['text'] as String? ?? '');
        return '已重写全文';
      case 'read_outline':
        final o = readOutline();
        return o.trim().isEmpty ? '(大纲目前为空)' : o;
      case 'set_outline':
        writeOutline(args['text'] as String? ?? '');
        return '已更新大纲';
      case 'upsert_entry':
        return _upsertEntry(args);
      default:
        return lookup.call(name, args);
    }
  }

  Future<String> _upsertEntry(Map<String, dynamic> args) async {
    final kind = EntryKind.values.asNameMap()[args['kind']?.toString()];
    final name = args['name']?.toString().trim() ?? '';
    final rawFields = args['fields'];
    if (kind == null || name.isEmpty) return '失败:kind 或 name 无效';
    final valid = {for (final f in entryFieldsFor(kind)) f.key};
    final fields = <String, String>{};
    if (rawFields is Map) {
      for (final e in rawFields.entries) {
        if (valid.contains(e.key.toString()) && e.value != null) {
          fields[e.key.toString()] = e.value.toString();
        }
      }
    }
    if (fields.isEmpty) return '失败:fields 为空或 key 不合法(可用:${valid.join('、')})';
    final all = await db.allEntriesOf(novelId);
    Entry? target;
    for (final e in all) {
      if (e.kind == kind.name && e.name == name) {
        target = e;
        break;
      }
    }
    if (target == null) {
      await db.createEntry(novelId, kind, name, encodeEntryContent(fields));
      return '已创建${kind.label}「$name」';
    }
    final merged = parseEntryContent(target.content)..addAll(fields);
    await db.updateEntry(target.id, target.name, encodeEntryContent(merged));
    return '已更新${kind.label}「$name」的字段:${fields.keys.join('、')}';
  }
}
