import 'db.dart';
import 'entry_fields.dart';
import 'novel_tools.dart';

/// 各类型合法字段 key 一览,内嵌进工具 description 免得模型猜
final _fieldKeysDesc = [
  for (final k in EntryKind.values)
    '${k.name}=${entryFieldsFor(k).map((f) => f.key).join('/')}'
].join('; ');

/// 写作 agent 的正文编辑工具(类编程 agent 的 read/write 范式)
final writingToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'read_content',
      'description':
          '读取当前小节正文全文,每行带行号前缀"N| ";末尾附作者当前高亮(如有);修改前必须先读,replace_text 的原文不含行号前缀',
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
      'name': 'polish_text',
      'description': '润色专用替换:只修标点、分段、错字与读不通的地方,句子骨架与作者的用词必须留着;'
          'old_text 须与正文逐字一致且全文唯一,一次只润一段。'
          '系统会校验改动幅度,判定为重写或增添内容时直接拒绝,这是硬限制;'
          '确实需要改写或补写时改用 replace_text,并向作者说明理由',
      'parameters': {
        'type': 'object',
        'properties': {
          'old_text': {'type': 'string', 'description': '要润色的原文片段(逐字)'},
          'new_text': {'type': 'string', 'description': '润色后的文字'},
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
      'description': '读取当前小节的大纲',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_outline',
      'description': '更新当前小节的大纲(情节变化后同步,或按作者要求调整)',
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
      'description': '新增或更新一张设定卡:同名合并字段,不存在则创建。fields 限模板字段(不确定时先用 get_kind_template 查);fields.name 可改名;links 记录与其他卡片的定向关联',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore', 'foreshadow'],
          },
          'name': {'type': 'string', 'description': '条目名称(现名)'},
          'fields': {
            'type': 'object',
            'description':
                '字段内容,key 必须出自该类型的合法列表——$_fieldKeysDesc。更新时只给需修改的 key;含 "name" 时表示改名;字段含义与填写指南用 get_kind_template 查',
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
            'enum': ['character', 'location', 'item', 'scene', 'lore', 'foreshadow'],
          },
          'name': {'type': 'string', 'description': '条目名称(必须完全一致)'},
        },
        'required': ['kind', 'name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'upsert_set',
      'description': '创建或更新设定集(若干设定类卡片的命名组合,作者可整组挂载到写作会话):同名更新(entries 全量替换),不存在则创建',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '集名(现名)'},
          'new_name': {'type': 'string', 'description': '改名时的新集名,可选'},
          'entries': {
            'type': 'array',
            'description': '集内设定卡名列表(仅限设定类,必须已存在);全量替换',
            'items': {'type': 'string'},
          },
        },
        'required': ['name', 'entries'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'delete_set',
      'description': '删除设定集(不影响集内卡片本身);仅在作者明确要求时使用',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': '集名(必须完全一致)'},
        },
        'required': ['name'],
      },
    },
  },
];

/// 润色的改动预算:剥离标点空白后,文字的编辑距离占原文比例上限
const _polishMaxRatio = 0.5;

/// 润色的增量预算:文字只能微增(补漏字),涨得多就是在加描写
const _polishMaxGrowRatio = 0.1;

/// 单次润色片段的字数上限:逼着一段一段来,改动小才便于作者审批
const polishMaxLen = 1200;

/// 标点与空白;剥掉后再比对,所以调标点、改分段永远不占改动预算
final _punctSpace = RegExp(r'[\s\p{P}\p{S}]', unicode: true);

/// 只留文字的骨架,润色比对的基准
String _coreText(String s) => s.replaceAll(_punctSpace, '');

/// 编辑距离(滚动两行,只为算改动幅度,不需要回溯路径)
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final swap = prev;
    prev = cur;
    cur = swap;
  }
  return prev[b.length];
}

/// 润色守则的系统层校验:通过返回 null,否则返回给模型的失败原因。
/// 标点、分段免费;错字、漏字、赘词在预算内;重写句子与增添内容挡下。
String? polishRejection(String oldText, String newText) {
  if (oldText.length > polishMaxLen) {
    return '失败:润色片段过长(${oldText.length} 字),请一段一段来,单次不超过 $polishMaxLen 字';
  }
  final oldCore = _coreText(oldText);
  final newCore = _coreText(newText);
  // 纯标点与分段调整,直接放行
  if (oldCore == newCore) return null;
  final grow = newCore.length - oldCore.length;
  final growLimit = (oldCore.length * _polishMaxGrowRatio).floor() + 2;
  if (grow > growLimit) {
    return '失败:润色不得增添内容(文字从 ${oldCore.length} 字涨到 ${newCore.length} 字);'
        '只修标点、分段、错字与读不通的地方。要补描写请改用 replace_text 并说明理由';
  }
  final base = oldCore.isEmpty ? 1 : oldCore.length;
  final dist = _editDistance(oldCore, newCore);
  final limit = (base * _polishMaxRatio).floor();
  if (dist > (limit < 1 ? 1 : limit)) {
    return '失败:改动幅度 ${(dist * 100 / base).round()}% 超出润色上限 '
        '${(_polishMaxRatio * 100).round()}%,这是重写不是润色;'
        '请留住原句骨架与作者的用词,或改用 replace_text 并向作者说明理由';
  }
  return null;
}

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
        return _replaceOne(args, polish: false);
      case 'polish_text':
        return _replaceOne(args, polish: true);
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
      case 'upsert_set':
        return _upsertSet(args);
      case 'delete_set':
        return _deleteSet(args);
      default:
        return lookup.call(name, args);
    }
  }

  /// 唯一匹配替换;polish 为真时先过润色守则校验
  String _replaceOne(Map<String, dynamic> args, {required bool polish}) {
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
    if (polish) {
      final rejection = polishRejection(oldText, newText);
      if (rejection != null) return rejection;
    }
    writeContent(content.replaceFirst(oldText, newText));
    if (!polish) return '已替换';
    return _coreText(oldText) == _coreText(newText)
        ? '已润色(只动了标点与分段)'
        : '已润色';
  }

  Future<String> _upsertSet(Map<String, dynamic> args) async {
    final name = args['name']?.toString().trim() ?? '';
    if (name.isEmpty) return '失败:name 不能为空';
    final rawEntries = args['entries'];
    if (rawEntries is! List) return '失败:entries 必须是卡片名数组';
    final all = await db.allEntriesOf(novelId);
    final ids = <int>[];
    final missed = <String>[];
    for (final r in rawEntries) {
      final n = r?.toString().trim() ?? '';
      if (n.isEmpty) continue;
      Entry? found;
      for (final e in all) {
        if (e.kind == EntryKind.lore.name && e.name == n) {
          found = e;
          break;
        }
      }
      found == null ? missed.add(n) : ids.add(found.id);
    }
    if (missed.isNotEmpty) {
      return '失败:未找到设定类卡片:${missed.join('、')}(仅设定类可入集)';
    }
    final newName = args['new_name']?.toString().trim();
    final sets = await db.setsOf(novelId);
    for (final s in sets) {
      if (s.name == name) {
        await db.updateSet(
            s.id, (newName?.isNotEmpty ?? false) ? newName! : name,
            ids.join(','));
        return '已更新设定集「$name」(${ids.length} 张卡${(newName?.isNotEmpty ?? false) ? ',改名为「$newName」' : ''})';
      }
    }
    await db.createSet(novelId, name, ids.join(','));
    return '已创建设定集「$name」(${ids.length} 张卡);作者可在挂载设定里整组启用';
  }

  Future<String> _deleteSet(Map<String, dynamic> args) async {
    final name = args['name']?.toString().trim() ?? '';
    if (name.isEmpty) return '失败:name 不能为空';
    final sets = await db.setsOf(novelId);
    for (final s in sets) {
      if (s.name == name) {
        await db.deleteSet(s.id);
        return '已删除设定集「$name」(集内卡片保留)';
      }
    }
    return '失败:未找到设定集「$name」';
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
