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
          '读取本节正文全文:首行给出字数与段数,其后每行带行号前缀"N| ";末尾附作者当前高亮(如有)。'
          '改动正文前必须先调用它(系统会拦下未读就改的调用);old_text 要用不带行号前缀的原文',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'replace_text',
      'description': '精确替换正文中的一段文字;old_text 须与正文逐字一致且全文唯一'
          '(行号前缀、空白、全角半角标点、引号样式的差异系统会容错,但文字本身不能改),替换后回报所在行号',
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
      'description': '在正文结尾追加内容(续写);一次一段场景,回报本节最新字数,便于按计划推进篇幅',
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
      'description': '整体重写正文;仅当作者明确要求推翻重写时使用。读一遍现有正文后调用;'
          '新文字明显短于原文且未给 reason 会被系统判为误删并拒绝',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '新的正文全文'},
          'reason': {
            'type': 'string',
            'description': '大幅删减或改写时的理由(可选);写清为什么必须整篇重写'
          },
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
      'name': 'check_prose',
      'description': '体检当前正文:字数/最长段、连续同起手、字数板结、破折号与"不是…而是"、AI 腔套话与直述情绪的命中位置。'
          '写完一段后调用它拿到可核对的客观信号,按命中项就地改,改完再体检一次,直到命中数下降',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'offer_candidates',
      'description': '给作者出 2~3 个风格不同的候选版本,由他在界面上挑一个落地(散文质量靠多版对比择优)。'
          '用于:作者说"给我几个版本/换个写法/不满意/太 AI 了",或开篇、关键转折、结尾这类定调处而他没指定怎么写。'
          '普通续写与落实作者明确要求时不要用,直接写。调用后本轮就结束,等作者选',
      'parameters': {
        'type': 'object',
        'properties': {
          'mode': {
            'type': 'string',
            'enum': ['append', 'replace'],
            'description': 'append=作为续写追加到文末;replace=替换 anchor 指的那一段'
          },
          'anchor': {
            'type': 'string',
            'description': 'mode=replace 时必填:要被替换的原文片段(逐字,取自 read_content)'
          },
          'candidates': {
            'type': 'array',
            'description': '候选版本,2~3 个,彼此走不同的路子(不是同一段话的微调)',
            'items': {
              'type': 'object',
              'properties': {
                'label': {
                  'type': 'string',
                  'description': '一句话说明这版的路子,如"冷处理,留白"'
                },
                'text': {'type': 'string', 'description': '这一版的正文文字'},
              },
              'required': ['label', 'text'],
            },
          },
        },
        'required': ['mode', 'candidates'],
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

/// 归一化后的文本与其「归一化位置 → 原文位置」回映表
class _Norm {
  _Norm(this.text, this.starts, this.lens, this.unitToEntry);

  final String text;

  /// 每个保留下来的字符在原文中的起始下标
  final List<int> starts;

  /// 每个保留下来的字符在原文中占的 code unit 数(代理对为 2)
  final List<int> lens;

  /// 归一化串里每个 code unit 对应的保留字符序号
  final List<int> unitToEntry;

  int endOf(int entry) => starts[entry] + lens[entry];
}

/// read_content 输出里的行号前缀,如 "12| "、"7 |"
final _lineNoPrefix = RegExp(r'[ \t]*\d+[ \t]*[|｜][ \t]?');

/// 逐字符扫描 [s],[keep] 返回 null 表示丢弃(也可返回替换后的字符)
_Norm _normWith(String s, String? Function(int index, String ch) keep) {
  final buf = StringBuffer();
  final starts = <int>[];
  final lens = <int>[];
  final unitToEntry = <int>[];
  var i = 0;
  while (i < s.length) {
    final cu = s.codeUnitAt(i);
    // 代理对整体处理,避免半截字符
    final len = cu >= 0xD800 && cu <= 0xDBFF && i + 1 < s.length ? 2 : 1;
    final ch = s.substring(i, i + len);
    final out = keep(i, ch);
    if (out != null) {
      final entry = starts.length;
      buf.write(out);
      starts.add(i);
      lens.add(len);
      for (var k = 0; k < out.length; k++) {
        unitToEntry.add(entry);
      }
    }
    i += len;
  }
  return _Norm(buf.toString(), starts, lens, unitToEntry);
}

/// 恒等归一化(只为了统一回映表)
_Norm _normPlain(String s) => _normWith(s, (i, ch) => ch);

/// 归一化一:删掉每行开头的行号前缀(模型常把 "12| " 一起抄回来)
_Norm _normNoLineNo(String s) {
  final skip = <int>{};
  var lineStart = 0;
  while (lineStart < s.length) {
    final nl = s.indexOf('\n', lineStart);
    final lineEnd = nl < 0 ? s.length : nl;
    final m = _lineNoPrefix.matchAsPrefix(s, lineStart);
    if (m != null && m.end > lineStart && m.end <= lineEnd) {
      for (var k = lineStart; k < m.end; k++) {
        skip.add(k);
      }
    }
    if (nl < 0) break;
    lineStart = nl + 1;
  }
  return _normWith(s, (i, ch) => skip.contains(i) ? null : ch);
}

/// 归一化二:只留骨架字符——丢掉空白与全部标点符号,全角转半角、拉丁大小写归一。
/// 模型复述原文时最常见的偏差(引号样式、逗号全半角、空行与分段)都在这一层被吸收
_Norm _normCore(String s) => _normWith(s, (i, ch) {
      if (_punctSpace.hasMatch(ch)) return null;
      final cu = ch.codeUnitAt(0);
      if (cu >= 0xFF01 && cu <= 0xFF5E) {
        return String.fromCharCode(cu - 0xFEE0).toLowerCase();
      }
      return ch.toLowerCase();
    });

/// 在归一化正文里找归一化片段,回映出原文区间与所在行号(行号最多报 6 个)
({int count, int start, int end, List<int> lines}) _scanNorm(
    String content, _Norm c, String needle) {
  const none = (count: 0, start: -1, end: -1, lines: <int>[]);
  if (needle.isEmpty || c.text.isEmpty) return none;
  final hits = <int>[];
  var from = 0;
  while (hits.length < 33) {
    final i = c.text.indexOf(needle, from);
    if (i < 0) break;
    hits.add(i);
    from = i + 1;
  }
  if (hits.isEmpty) return none;
  final lines = <int>[
    for (final i in hits.take(6))
      '\n'.allMatches(content.substring(0, c.starts[c.unitToEntry[i]])).length + 1
  ];
  final first = hits.first;
  final firstEntry = c.unitToEntry[first];
  final lastEntry = c.unitToEntry[first + needle.length - 1];
  return (
    count: hits.length,
    start: c.starts[firstEntry],
    end: c.endOf(lastEntry),
    lines: lines,
  );
}

/// 定位失败时的近似提示:找与片段首行最像的正文行,帮模型自己发现记错的地方
String _nearMissHint(String content, String fragment) {
  final firstLine = fragment
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  final probe = _normCore(firstLine).text;
  if (probe.length < 4) return '';
  final head = probe.length <= 14 ? probe : probe.substring(0, 14);
  var bestLine = 0;
  var bestLen = 0;
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final t = _normCore(lines[i]).text;
    if (t.isEmpty) continue;
    var n = 0;
    while (n < head.length && n < t.length && head[n] == t[n]) {
      n++;
    }
    if (n > bestLen) {
      bestLen = n;
      bestLine = i + 1;
    }
  }
  if (bestLen < 4 || bestLine == 0) return '';
  final raw = lines[bestLine - 1].trim();
  final brief = raw.length <= 40 ? raw : '${raw.substring(0, 40)}…';
  return ';最接近的是第 $bestLine 行「$brief」';
}

/// 正文片段的定位结果:唯一命中给出原文区间,否则给出可直接回给模型的自愈说明
class FragmentMatch {
  const FragmentMatch._(this.start, this.end, this.how, this.failure);

  final int? start;
  final int? end;

  /// 命中方式(逐字 / 忽略行号前缀 / 忽略空白与标点);未命中为 null
  final String? how;

  /// 未命中或命中多处的说明
  final String? failure;

  bool get found => start != null;
}

/// 字数:不计空白,与作者对"多少字"的直觉一致
int proseWordCount(String s) =>
    s.replaceAll(RegExp(r'\s'), '').length;

/// 常见 AI 腔与偷懒信号;体检报告据此给模型可核对的命中项
const _aiTellPatterns = <String, String>{
  '不禁': '情绪套话',
  '竟然': '情绪套话',
  '涌上': '情绪套话',
  '仿佛': '比喻词',
  '宛如': '比喻词',
  '好似': '比喻词',
  '缓缓': '副词堆砌',
  '轻轻': '副词堆砌',
  '淡淡': '副词堆砌',
  '微微': '副词堆砌',
  '眼眸': '套路特写',
  '眸光': '套路特写',
  '后来': '概述词',
  '于是': '概述词',
  '经过': '概述词',
  '命运': '升华词',
  '宿命': '升华词',
  '救赎': '升华词',
};

/// 直述情绪的写法(该改成外在呈现)
final _flatEmotion = RegExp('很(难过|伤心|生气|高兴|愤怒|害怕|紧张)|非常(难过|生气|高兴)');

/// 正文体检:给模型一份**外部**可核对的自检信号。
/// 依据:同 context 的自我批评对长文基本无效,带 pass/fail 的外部反馈才有效
String proseCheckReport(String content) {
  final paras = [
    for (final l in content.split('\n'))
      if (l.trim().isNotEmpty) l.trim()
  ];
  if (paras.isEmpty) return '(正文为空,没有可体检的内容)';
  final lens = [for (final p in paras) proseWordCount(p)];
  final longest = lens.reduce((a, b) => a > b ? a : b);
  final buf = StringBuffer('【正文体检】\n');
  buf.writeln('字数 ${proseWordCount(content)};自然段 ${paras.length};最长一段 $longest 字'
      '${longest > 400 ? '(偏长,考虑拆段)' : ''}');

  // 连续同一起手(段落开头字)
  final hits = <String>[];
  var i = 0;
  while (i < paras.length) {
    var j = i;
    final head = paras[i].substring(0, 1);
    while (j + 1 < paras.length && paras[j + 1].startsWith(head)) {
      j++;
    }
    if (j - i + 1 >= 3) {
      hits.add('第 ${i + 1}-${j + 1} 段都以「$head」起手,句式雷同');
    }
    i = j + 1;
  }
  // 连续两段以上同长(节奏板结)
  var k = 0;
  while (k + 2 < lens.length) {
    if (lens[k] == lens[k + 1] && lens[k + 1] == lens[k + 2]) {
      hits.add('第 ${k + 1}-${k + 3} 段字数完全相同,节奏板结');
      k += 3;
    } else {
      k++;
    }
  }
  if (content.contains('——')) {
    hits.add('破折号 ${'——'.allMatches(content).length} 处,注意别滥用');
  }
  if (content.contains('不是') && content.contains('而是')) {
    hits.add('出现「不是…而是…」对举句式,是典型 AI 腔');
  }

  final tells = <String, List<int>>{};
  for (var p = 0; p < paras.length; p++) {
    for (final kw in _aiTellPatterns.keys) {
      final n = kw.allMatches(paras[p]).length;
      if (n > 0) (tells[kw] ??= []).add(p + 1);
    }
  }
  final flat = [
    for (var p = 0; p < paras.length; p++)
      if (_flatEmotion.hasMatch(paras[p])) p + 1
  ];
  final last = paras.length - 1;
  final ending = _aiTellPatterns.entries
      .where((e) => e.value == '升华词' && paras[last].contains(e.key))
      .map((e) => e.key)
      .toList();

  var total = 0;
  for (final e in tells.entries) {
    total += e.value.length;
    buf.writeln('- ${e.key}(${_aiTellPatterns[e.key]})×${e.value.length}:第 ${e.value.join('、')} 段');
  }
  if (flat.isNotEmpty) {
    total += flat.length;
    buf.writeln('- 直述情绪(${_flatEmotion.pattern.split('|').first}…):第 ${flat.join('、')} 段;改成外在呈现');
  }
  if (ending.isNotEmpty) {
    buf.writeln('- 结尾段出现${ending.join('、')},疑似升华收尾;换成具体的动作或悬置');
  }
  for (final h in hits) {
    buf.writeln('- $h');
  }
  if (total == 0 && hits.isEmpty) {
    buf.writeln('未发现套话与句式问题;仍请按文笔手册逐条自查场景/阻力/潜文本/连续性');
  } else {
    buf.writeln('命中项逐条就地改掉(replace_text),改完再体检一次,命中数应当下降');
  }
  return buf.toString().trimRight();
}

bool _isPunctOrSpace(String ch) =>
    ch.isNotEmpty && _punctSpace.hasMatch(ch.substring(0, 1));

/// 容错命中时把片段自带的收尾标点/空白一并纳入区间,
/// 否则替换后会留下重复标点(如原文"没人。"→ 新文"没人。"接在残留的"。"前)
({int start, int end}) _expandLooseSpan(
    String content, String fragment, int start, int end) {
  if (_isPunctOrSpace(fragment[0])) {
    while (start > 0 && _isPunctOrSpace(content[start - 1])) {
      start--;
    }
  }
  if (_isPunctOrSpace(fragment[fragment.length - 1])) {
    while (end < content.length && _isPunctOrSpace(content[end])) {
      end++;
    }
  }
  return (start: start, end: end);
}

/// 定位正文片段:逐字 → 忽略行号前缀 → 忽略空白与标点三级容错。
/// 只在唯一命中时返回区间;0 处或多处都给出让模型能自己纠正的说明。
FragmentMatch locateFragment(String content, String fragment) {
  if (fragment.trim().isEmpty) {
    return const FragmentMatch._(null, null, null, '失败:片段为空');
  }
  final tries = <({String how, _Norm c, String n})>[
    (how: '逐字', c: _normPlain(content), n: _normPlain(fragment).text),
    (how: '忽略行号前缀', c: _normNoLineNo(content), n: _normNoLineNo(fragment).text),
    (how: '忽略空白与标点', c: _normCore(content), n: _normCore(fragment).text),
  ];
  for (final t in tries) {
    final r = _scanNorm(content, t.c, t.n);
    if (r.count == 1) {
      var span = (start: r.start, end: r.end);
      if (t.how != '逐字') {
        span = _expandLooseSpan(content, fragment, r.start, r.end);
      }
      return FragmentMatch._(span.start, span.end, t.how, null);
    }
    if (r.count > 1) {
      return FragmentMatch._(null, null, null,
          '失败:该片段在正文出现 ${r.count} 处(第 ${r.lines.join('、')} 行),请给更长的唯一片段');
    }
  }
  return FragmentMatch._(
      null,
      null,
      null,
      '失败:正文中没有这段文字(已按逐字、忽略行号、忽略空白与标点三种方式比对过,本节共 '
      '${proseWordCount(content)} 字)${_nearMissHint(content, fragment)};'
      '请先 read_content 核对原文,再逐字复制要改的片段');
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

  /// 本轮是否已读过正文:没读就改等于盲改,定位与判断都会失准,系统层直接拦下
  bool _readContentThisTurn = false;

  /// 本轮定位失败次数:连着失败就别再硬试同一招(Cline 的逃生舱做法)
  int _locateFailures = 0;

  /// 连续两次定位失败后,把"改用整段重写"这条退路明确告诉模型
  String _withEscape(String failure) {
    _locateFailures++;
    if (_locateFailures < 2) return failure;
    return '$failure\n(本段已连续 $_locateFailures 次定位失败:先 read_content 看准原文;'
        '确实要整段推翻时用 set_content 并在 reason 里写明理由)';
  }

  Future<String> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'read_content':
        _readContentThisTurn = true;
        final c = readContent();
        if (c.trim().isEmpty) return '(正文目前为空,本节共 0 字)';
        final lines = c.split('\n');
        final paragraphs =
            lines.where((l) => l.trim().isNotEmpty).length;
        final numbered = [
          for (var i = 0; i < lines.length; i++) '${i + 1}| ${lines[i]}'
        ].join('\n');
        final stat = '【本节正文 ${proseWordCount(c)} 字,$paragraphs 个自然段,共 ${lines.length} 行】';
        final h = readHighlight();
        if (h == null || h.end > c.length) return '$stat\n$numbered';
        final frag = c.substring(h.start, h.end);
        final startLine = '\n'.allMatches(c.substring(0, h.start)).length + 1;
        final endLine = startLine + '\n'.allMatches(frag).length;
        final range =
            endLine == startLine ? '第 $startLine 行' : '第 $startLine-$endLine 行';
        final brief =
            frag.length <= 80 ? frag : '${frag.substring(0, 80)}…';
        return '$stat\n$numbered\n\n【作者当前高亮($range)】$brief';
      case 'replace_text':
        return _replaceOne(args, polish: false);
      case 'polish_text':
        return _replaceOne(args, polish: true);
      case 'append_text':
        final text = args['text'] as String? ?? '';
        if (text.trim().isEmpty) return '失败:text 为空';
        final content = readContent();
        final next =
            content.trim().isEmpty ? text : '${content.trimRight()}\n\n$text';
        writeContent(next);
        return '已追加 ${proseWordCount(text)} 字;本节正文现 ${proseWordCount(next)} 字';
      case 'set_content':
        if (!_readContentThisTurn) {
          return '失败:整体重写前必须先 read_content 读一遍现有正文,确认哪些内容要保留';
        }
        final text = args['text'] as String? ?? '';
        final cur = readContent();
        final reason = args['reason']?.toString().trim() ?? '';
        final nowLen = proseWordCount(cur);
        final newLen = proseWordCount(text);
        final cut = nowLen - newLen;
        if (reason.isEmpty && nowLen > 0 && cut > nowLen * 0.4) {
          return '失败:新正文 $newLen 字,比现有 $nowLen 字少了 $cut 字,'
              '像是误删了作者的内容;确实要大幅删减就用 replace_text 逐段处理,'
              '或在 reason 里写明删减理由后重试';
        }
        writeContent(text);
        return '已重写全文(${proseWordCount(text)} 字${reason.isEmpty ? '' : ';理由:$reason'})';
      case 'set_highlight':
        return highlight(args['text'] as String? ?? '');
      case 'check_prose':
        final c = readContent();
        if (c.trim().isEmpty) return '(正文为空,没有可体检的内容)';
        return proseCheckReport(c);
      case 'offer_candidates':
        return _offerCandidates(args);
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

  /// 校验候选参数;真正的"选哪个"由作者在界面上点,这里只负责把关
  String _offerCandidates(Map<String, dynamic> args) {
    final mode = args['mode']?.toString() ?? '';
    if (mode != 'append' && mode != 'replace') {
      return '失败:mode 只能是 append 或 replace';
    }
    final raw = args['candidates'];
    if (raw is! List || raw.length < 2) {
      return '失败:candidates 至少给 2 个版本,让作者有得挑';
    }
    final texts = <String>[];
    for (final c in raw.take(4)) {
      if (c is! Map) continue;
      final t = c['text']?.toString().trim() ?? '';
      if (t.isEmpty) continue;
      texts.add(t);
    }
    if (texts.length < 2) return '失败:候选版本内容为空,至少两个版本要有正文';
    if (texts.toSet().length < texts.length) {
      return '失败:候选之间要有实质差别,不能是同一段文字的重复';
    }
    if (mode == 'replace') {
      final anchor = args['anchor']?.toString() ?? '';
      if (anchor.trim().isEmpty) {
        return '失败:mode=replace 时必须给 anchor(要替换的原文片段)';
      }
      final m = locateFragment(readContent(), anchor);
      if (!m.found) return m.failure!;
    }
    return '已把 ${texts.length} 个候选交给作者挑选;等他选完再继续,不要自己落地';
  }

  /// 唯一匹配替换;容错定位,polish 为真时再过润色守则校验
  String _replaceOne(Map<String, dynamic> args, {required bool polish}) {
    final oldText = args['old_text'] as String? ?? '';
    final newText = args['new_text'] as String? ?? '';
    if (oldText.trim().isEmpty) return '失败:old_text 为空';
    if (!_readContentThisTurn) {
      return '失败:动正文前必须先 read_content 读一遍当前正文,再照原文给出 old_text';
    }
    final content = readContent();
    if (oldText == newText) return '失败:old_text 与 new_text 完全相同,无需修改';
    final m = locateFragment(content, oldText);
    if (!m.found) return _withEscape(m.failure!);
    if (polish) {
      final rejection = polishRejection(oldText, newText);
      if (rejection != null) return rejection;
    }
    writeContent(content.replaceRange(m.start!, m.end!, newText));
    final line = '\n'.allMatches(content.substring(0, m.start!)).length + 1;
    final where = m.how == '逐字' ? '第 $line 行' : '第 $line 行,按「${m.how}」定位';
    if (!polish) return '已替换($where)';
    return _coreText(oldText) == _coreText(newText)
        ? '已润色(只动了标点与分段)'
        : '已润色($where)';
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
