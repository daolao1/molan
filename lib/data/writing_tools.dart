import 'db.dart';
import 'entry_fields.dart';
import 'novel_tools.dart';

/// 写作 agent 的正文编辑工具(类编程 agent 的 read/write 范式)
const writingToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'read_content',
      'description':
          '读取当前事件正文全文,每行带行号前缀"N| ";末尾附作者当前高亮(如有);修改前必须先读,replace_text 的原文不含行号前缀',
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
      'name': 'set_highlight',
      'description': '在正文编辑器里高亮标记一段文字,帮作者定位(如“帮我找到写雨的那段”);不改动正文',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': '要高亮的原文片段(逐字唯一匹配);传空字符串表示清除高亮'
          },
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
      'description': '新增或更新一张设定卡:同名合并字段,不存在则创建。fields 限模板字段;fields.name 可改名;links 记录与其他卡片的定向关联',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore'],
          },
          'name': {'type': 'string', 'description': '条目名称(现名)'},
          'fields': {
            'type': 'object',
            'description':
                '字段内容,key 限该类型的模板字段(中文标签亦可);更新时只给需修改的;含 "name" 时表示改名;放不进具体字段的内容并入备注',
          },
          'links': {
            'type': 'array',
            'description':
                '从本卡片指向其他卡片的定向关联 [{"to":"卡片名","label":"关联描述"}];人物关系、场景归属(label“位于”)、物品持有等都用它;同一对卡片可有多条;to 必须已存在',
            'items': {
              'type': 'object',
              'properties': {
                'to': {'type': 'string'},
                'label': {'type': 'string'},
              },
              'required': ['to', 'label'],
            },
          },
        },
        'required': ['kind', 'name', 'fields'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'delete_entry',
      'description': '删除一张设定卡(连同其全部关联);仅在作者明确要求删除时使用',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore'],
          },
          'name': {'type': 'string', 'description': '条目名称(必须完全一致)'},
        },
        'required': ['kind', 'name'],
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
    required this.highlight,
    required this.readHighlight,
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

  /// 高亮标记原文片段(空串=清除);返回结果消息
  final String Function(String fragment) highlight;

  /// 当前高亮字符区间;无则 null
  final ({int start, int end})? Function() readHighlight;

  final AppDatabase db;
  final int novelId;
  final NovelToolExecutor lookup;

  Future<String> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'read_content':
        final c = readContent();
        if (c.trim().isEmpty) return '(正文目前为空)';
        final lines = c.split('\n');
        final numbered = [
          for (var i = 0; i < lines.length; i++) '${i + 1}| ${lines[i]}'
        ].join('\n');
        final h = readHighlight();
        if (h == null || h.end > c.length) return numbered;
        final frag = c.substring(h.start, h.end);
        final startLine = '\n'.allMatches(c.substring(0, h.start)).length + 1;
        final endLine = startLine + '\n'.allMatches(frag).length;
        final range =
            endLine == startLine ? '第 $startLine 行' : '第 $startLine-$endLine 行';
        final brief =
            frag.length <= 80 ? frag : '${frag.substring(0, 80)}…';
        return '$numbered\n\n【作者当前高亮($range)】$brief';
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
      case 'set_highlight':
        return highlight(args['text'] as String? ?? '');
      case 'read_outline':
        final o = readOutline();
        return o.trim().isEmpty ? '(大纲目前为空)' : o;
      case 'set_outline':
        writeOutline(args['text'] as String? ?? '');
        return '已更新大纲';
      case 'upsert_entry':
        return _upsertEntry(args);
      case 'delete_entry':
        return _deleteEntry(args);
      default:
        return lookup.call(name, args);
    }
  }

  Future<String> _deleteEntry(Map<String, dynamic> args) async {
    final kind = EntryKind.values.asNameMap()[args['kind']?.toString()];
    final name = args['name']?.toString().trim() ?? '';
    if (kind == null || name.isEmpty) return '失败:kind 或 name 无效';
    final all = await db.allEntriesOf(novelId);
    for (final e in all) {
      if (e.kind == kind.name && e.name == name) {
        await db.deleteEntry(e.id);
        return '已删除${kind.label}「$name」及其关联';
      }
    }
    return '失败:未找到${kind.label}「$name」';
  }

  Future<String> _upsertEntry(Map<String, dynamic> args) async {
    final kind = EntryKind.values.asNameMap()[args['kind']?.toString()];
    final name = args['name']?.toString().trim() ?? '';
    if (kind == null || name.isEmpty) return '失败:kind 或 name 无效';
    final fields = <String, String>{};
    final rawFields = args['fields'];
    final validKeys = {for (final f in entryFieldsFor(kind)) f.key};
    final invalid = <String>[];
    if (rawFields is Map) {
      for (final e in rawFields.entries) {
        if (e.value == null) continue;
        // 中文标签 key 归一到模板 key;模板外的拒绝,保持卡片结构稳定
        final key = normalizeFieldKey(kind, e.key.toString());
        if (key == 'name' || validKeys.contains(key)) {
          fields[key] = e.value.toString();
        } else {
          invalid.add(e.key.toString());
        }
      }
    }
    if (invalid.isNotEmpty) {
      return '失败:字段 ${invalid.join('、')} 不属于${kind.label}模板;'
          '可用字段:${[for (final f in entryFieldsFor(kind)) '${f.key}(${f.label})'].join('、')};'
          '放不进具体字段的内容并入备注类字段';
    }
    final newName = fields.remove('name')?.trim();
    final all = await db.allEntriesOf(novelId);
    final hasLinks = args['links'] is List && (args['links'] as List).isNotEmpty;
    if (fields.isEmpty && newName == null && !hasLinks) {
      return '失败:没有可更新的内容';
    }
    Entry? target;
    for (final e in all) {
      if (e.kind == kind.name && e.name == name) {
        target = e;
        break;
      }
    }
    if (target == null) {
      final id = await db.createEntry(
          novelId, kind, newName ?? name, encodeEntryContent(fields));
      final linkNote = await _applyLinks(id, args['links'], all);
      return '已创建${kind.label}「${newName ?? name}」$linkNote';
    }
    final merged = parseEntryContent(target.content)..addAll(fields);
    await db.updateEntry(
        target.id, newName ?? target.name, encodeEntryContent(merged));
    final linkNote = await _applyLinks(target.id, args['links'], all);
    final parts = [
      if (fields.isNotEmpty) '字段:${fields.keys.join('、')}',
      if (newName != null) '改名为「$newName」',
    ];
    return '已更新${kind.label}「$name」(${parts.join(';')})$linkNote';
  }

  /// 逐条 upsert 通用关联;返回结果尾注
  Future<String> _applyLinks(int fromId, Object? raw, List<Entry> all) async {
    if (raw is! List || raw.isEmpty) return '';
    var ok = 0;
    final missed = <String>[];
    for (final r in raw) {
      if (r is! Map) continue;
      final to = r['to']?.toString().trim() ?? '';
      final label = r['label']?.toString().trim() ?? '';
      if (to.isEmpty) continue;
      Entry? toE;
      for (final e in all) {
        if (e.name == to && e.id != fromId) {
          toE = e;
          break;
        }
      }
      if (toE == null) {
        missed.add(to);
        continue;
      }
      await db.upsertLink(fromId, toE.id, label);
      ok++;
    }
    final notes = [
      if (ok > 0) '关联×$ok',
      if (missed.isNotEmpty) '未找到卡片:${missed.join('、')}',
    ];
    return notes.isEmpty ? '' : ';${notes.join(';')}';
  }
}
