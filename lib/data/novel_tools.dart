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
      'name': 'get_kind_template',
      'description': '查看某类设定卡的字段模板(key、含义、填写指南);新建或更新设定卡前先读,确保字段用对',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore', 'foreshadow'],
          }
        },
        'required': ['kind'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_entries',
      'description': '列出设定库里的条目名(可按类型过滤);确认"有没有这张卡、名字怎么写"时用它,别猜',
      'parameters': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['character', 'location', 'item', 'scene', 'lore', 'foreshadow'],
          }
        },
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_chapters',
      'description': '全书章节与小节目录:每章标题及其小节序号、名称、大纲、字数',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_event_content',
      'description': '读取某章某小节的正文(序号见 list_chapters);超过 4000 字只给一端,'
          'from_end=true 时取结尾。衔接上一节文风、承接前情时读它的结尾',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapter': {'type': 'integer', 'description': '章节序号,从 1 起'},
          'event': {'type': 'integer', 'description': '小节序号,从 1 起'},
          'from_end': {
            'type': 'boolean',
            'description': 'true=取正文结尾(默认取开头)'
          },
        },
        'required': ['chapter', 'event'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'search_content',
      'description': '在全书正文里检索关键词或句子,返回所在章/小节/行号与上下文;'
          '呼应前文、核对伏笔与他人已写过的措辞时用它查原文,不要凭记忆编造',
      'parameters': {
        'type': 'object',
        'properties': {
          'keyword': {'type': 'string', 'description': '要检索的词或句子(2 字以上)'},
          'limit': {'type': 'integer', 'description': '最多返回多少处,默认 12'},
        },
        'required': ['keyword'],
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
      case 'get_kind_template':
        final kind =
            EntryKind.values.asNameMap()[args['kind']?.toString()];
        return kind == null
            ? '失败:kind 无效,可选:${EntryKind.values.map((k) => k.name).join('、')}'
            : kindTemplateDoc(kind);
      case 'list_chapters':
        return _listChapters();
      case 'get_event_content':
        return _eventContent(args['chapter'], args['event'],
            fromEnd: args['from_end'] == true);
      case 'search_content':
        return _searchContent(args['keyword']?.toString() ?? '',
            limit: args['limit'] is int ? args['limit'] as int : 12);
      default:
        return '未知工具:$name';
    }
  }

  /// 全书正文关键词检索:给模型一条"回原文核对"的实路,而不是靠记忆编造
  Future<String> _searchContent(String keyword, {int limit = 12}) async {
    final kw = keyword.trim();
    if (kw.length < 2) return '失败:keyword 至少 2 个字';
    final cap = limit.clamp(1, 30);
    final chapters = await db.watchChapters(novelId).first;
    final buf = StringBuffer();
    var total = 0;
    for (var c = 0; c < chapters.length; c++) {
      final events = await db.eventsOf(chapters[c].id);
      for (var i = 0; i < events.length; i++) {
        final content = events[i].content;
        if (content.isEmpty) continue;
        var from = 0;
        while (true) {
          final at = content.indexOf(kw, from);
          if (at < 0) break;
          total++;
          if (total <= cap) {
            final line = '\n'.allMatches(content.substring(0, at)).length + 1;
            final start = at - 30 < 0 ? 0 : at - 30;
            final end = at + kw.length + 30 > content.length
                ? content.length
                : at + kw.length + 30;
            final snippet =
                content.substring(start, end).replaceAll('\n', '⏎');
            buf.writeln(
                '第 ${c + 1} 章《${chapters[c].title}》小节 ${i + 1}「${events[i].name}」第 $line 行:'
                '…$snippet…');
          }
          from = at + kw.length;
        }
      }
    }
    if (total == 0) return '全书正文中没有找到「$kw」';
    if (total > cap) buf.writeln('(共 $total 处,只列了前 $cap 处)');
    return buf.toString().trimRight();
  }

  Future<String> _listChapters() async {
    final chapters = await db.watchChapters(novelId).first;
    if (chapters.isEmpty) return '(本书还没有章节)';
    final buf = StringBuffer();
    for (var c = 0; c < chapters.length; c++) {
      buf.writeln('第 ${c + 1} 章《${chapters[c].title}》');
      final events = await db.eventsOf(chapters[c].id);
      for (var i = 0; i < events.length; i++) {
        final o = events[i].outline.trim();
        final len = events[i].content.length;
        buf.writeln(
            '  小节 ${i + 1}「${events[i].name.trim().isEmpty ? '未命名' : events[i].name}」(${len > 0 ? '$len 字' : '无正文'}):${o.isEmpty ? '(无大纲)' : o}');
      }
    }
    return buf.toString().trimRight();
  }

  Future<String> _eventContent(Object? chapterNo, Object? eventNo,
      {bool fromEnd = false}) async {
    final c = chapterNo is int ? chapterNo : int.tryParse('$chapterNo') ?? 0;
    final ev = eventNo is int ? eventNo : int.tryParse('$eventNo') ?? 0;
    final chapters = await db.watchChapters(novelId).first;
    if (c < 1 || c > chapters.length) {
      return '失败:章节序号 $c 越界(共 ${chapters.length} 章)';
    }
    final events = await db.eventsOf(chapters[c - 1].id);
    if (ev < 1 || ev > events.length) {
      return '失败:小节序号 $ev 越界(该章共 ${events.length} 个小节)';
    }
    final e = events[ev - 1];
    final content = e.content.trim();
    if (content.isEmpty) return '(该小节还没有正文)大纲:${e.outline}';
    const cap = 4000;
    final body = content.length <= cap
        ? content
        : fromEnd
            ? '…(前 ${content.length - cap} 字略,以下是结尾)\n${content.substring(content.length - cap)}'
            : '${content.substring(0, cap)}\n…(已截断,全文共 ${content.length} 字;'
                '要读结尾改传 from_end:true)';
    return '第 $c 章《${chapters[c - 1].title}》小节 $ev「${e.name}」'
        '(正文 ${content.length} 字)\n大纲:${e.outline}\n正文:\n$body';
  }

  Future<String> _entryDetail(String name) async {
    if (name.trim().isEmpty) {
      return '失败:未提供 name 参数;请以 {"name":"条目名"} 形式调用,条目名取自设定清单';
    }
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
      // 空字段也列出并附填写指南,让模型知道还有什么可补
      buf.writeln(v.isEmpty
          ? '${f.label}(${f.key}):(空——可填:${f.hint.replaceAll('\n', ' ')})'
          : '${f.label}(${f.key}):$v');
    }
    for (final x in extensionFields(kind, data).entries) {
      if (x.value.trim().isNotEmpty) buf.writeln('${x.key}:${x.value.trim()}');
    }
    return buf.toString().trimRight();
  }

  Future<String> _listEntries(String? kindName) async {
    final all = await db.allEntriesOf(novelId);
    final one = kindName == null
        ? null
        : EntryKind.values.asNameMap()[kindName.trim()];
    if (kindName != null && one == null) {
      return '失败:kind 无效,可选:${EntryKind.values.map((k) => k.name).join('、')}';
    }
    final kinds = one == null ? EntryKind.values : [one];
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
