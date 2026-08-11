import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'dart:convert';

import '../data/app_context.dart';
import '../data/db.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';
import '../data/writing_tools.dart';
import 'widgets.dart';

/// 事件编辑:大纲 + 正文 + 对话式写作 agent
class EventEditPage extends StatefulWidget {
  const EventEditPage(
      {super.key,
      required this.db,
      required this.novel,
      required this.chapter,
      required this.priorEvents,
      this.followingEvents = const [],
      this.event});

  final AppDatabase db;
  final Novel novel;
  final Chapter chapter;

  /// 本章中位于本事件之前的事件(供上下文)
  final List<ChapterEvent> priorEvents;

  /// 本章中位于本事件之后的事件(供前瞻)
  final List<ChapterEvent> followingEvents;
  final ChapterEvent? event;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _ChatMsg {
  _ChatMsg(this.isUser, this.text)
      : isChange = false,
        isTool = false,
        isReview = false,
        snapshot = null;

  _ChatMsg.change(this.text, this.snapshot)
      : isUser = false,
        isChange = true,
        isTool = false,
        isReview = false;

  _ChatMsg.tool(this.text, {this.toolName, this.toolArgs, this.toolResult})
      : isUser = false,
        isChange = false,
        isTool = true,
        isReview = false,
        snapshot = null;

  _ChatMsg.review(this.ops)
      : isUser = false,
        isChange = false,
        isTool = false,
        isReview = true,
        text = '',
        snapshot = null;

  final bool isUser;
  String text;
  final bool isChange;
  final bool isTool;
  final bool isReview;

  /// 审批面板引用的本轮写操作
  List<_ChatMsg>? ops;

  /// 工具调用详情(展开查看)
  String? toolName;
  Map<String, dynamic>? toolArgs;
  String? toolResult;
  bool expanded = false;

  /// 写操作的逆操作;返回 null=成功,否则为错误描述
  Future<String?> Function()? revert;

  /// 本轮改动前的快照(拒绝时恢复)
  final ({String outline, String content})? snapshot;

  /// null=待处理,true=已接受,false=已拒绝
  bool? reviewed;
}

class _EventEditPageState extends State<EventEditPage>
    with SingleTickerProviderStateMixin {
  // 切到对话页时自动滚到最新记录
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (_tab.index == 1) _scrollChat();
    });
  late final _outlineCtrl =
      TextEditingController(text: widget.event?.outline ?? '');
  late final _contentCtrl =
      HighlightController(text: widget.event?.content ?? '');
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  final _chatFocus = FocusNode();

  /// LLM 会话(system + 全部轮次,含工具调用过程)
  final List<Map<String, dynamic>> _messages = [];

  /// 展示用消息
  final List<_ChatMsg> _chatUi = [];

  /// 正文/大纲回退栈(每轮 AI 改动前压入)
  final List<({String outline, String content})> _history = [];
  bool _busy = false;
  bool _dirty = false;
  bool _stopRequested = false;
  Offset _lastTapPos = Offset.zero;

  /// 最近一次非空选区(web 上点按钮会失焦丢选区,用它兑底)
  TextSelection? _pinnedSel;
  String _pinnedText = '';

  void _trackSel() {
    final s = _contentCtrl.selection;
    if (s.isValid && !s.isCollapsed && s.end <= _contentCtrl.text.length) {
      _pinnedSel = s;
      _pinnedText = _contentCtrl.text;
    } else if (_contentCtrl.text != _pinnedText) {
      _pinnedSel = null;
    }
  }

  /// 当前可用选区:实时优先,否则用钉住的(文本未变时)
  TextSelection? get _effectiveSel {
    final s = _contentCtrl.selection;
    if (s.isValid && !s.isCollapsed) return s;
    final p = _pinnedSel;
    if (p != null && _contentCtrl.text == _pinnedText) return p;
    return null;
  }

  static const _toolLabels = {
    'read_content': '读取正文',
    'replace_text': '修改文字',
    'append_text': '续写正文',
    'set_content': '重写全文',
    'read_outline': '读取大纲',
    'set_outline': '更新大纲',
    'set_highlight': '高亮标记',
    'upsert_entry': '更新设定',
    'delete_entry': '删除设定',
    'get_entry_detail': '查阅设定',
    'list_entries': '列出条目',
  };

  PageSnapshot _ctxProvider() => PageSnapshot(
        novelId: widget.novel.id,
        detail: '正在编辑《${widget.novel.title}》章节《${widget.chapter.title}》的事件。\n'
            '事件大纲:${_outlineCtrl.text}\n当前正文:\n${_contentCtrl.text}',
      );

  @override
  void initState() {
    super.initState();
    AppContextRegistry.push(_ctxProvider);
    _contentCtrl.addListener(_trackSel);
    _restoreChat();
  }

  /// 归档的历史会话:[{title, at, messages, ui}]
  final List<Map<String, dynamic>> _archived = [];

  void _restoreChat() {
    final raw = widget.event?.chatLog ?? '';
    if (raw.trim().isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final archived = data['archived'];
      if (archived is List) {
        _archived.addAll([
          for (final a in archived)
            if (a is Map) a.cast<String, dynamic>()
        ]);
      }
      _restoreCurrent(data);
    } catch (_) {
      // 损坏的历史不阻断页面
    }
  }

  /// 从一个会话对象(含 messages/ui)恢复到当前对话
  void _restoreCurrent(Map data) {
    final msgs = data['messages'];
    if (msgs is List) {
      _messages.addAll([
        for (final m in msgs)
          if (m is Map) m.cast<String, dynamic>()
      ]);
    }
    final ui = data['ui'];
    if (ui is List) {
      for (final m in ui) {
        if (m is! Map) continue;
        final text = m['text']?.toString() ?? '';
        switch (m['t']) {
          case 'user':
            _chatUi.add(_ChatMsg(true, text));
          case 'ai':
            _chatUi.add(_ChatMsg(false, text));
          case 'tool':
            _chatUi.add(_ChatMsg.tool(
              text,
              toolName: m['name']?.toString(),
              toolArgs: m['args'] is Map
                  ? (m['args'] as Map).cast<String, dynamic>()
                  : null,
              toolResult: m['result']?.toString(),
            )..reviewed = m['reviewed'] is bool ? m['reviewed'] as bool : true);
          case 'change':
            _chatUi.add(_ChatMsg.change(text, null)
              ..reviewed = m['reviewed'] is bool ? m['reviewed'] as bool : true);
        }
      }
    }
  }

  /// 当前对话序列化(不含 archived);messages 拷贝一份,归档后 clear 不影响
  Map<String, dynamic> _currentSession() => {
        'messages': List.of(_messages),
        'ui': [
          for (final m in _chatUi)
            if (!m.isReview)
              {
              't': m.isChange
                  ? 'change'
                  : m.isTool
                      ? 'tool'
                      : m.isUser
                          ? 'user'
                          : 'ai',
              'text': m.text,
              if (m.isChange) 'reviewed': m.reviewed ?? true,
              if (m.isTool && m.toolName != null) 'name': m.toolName,
              if (m.isTool && m.toolArgs != null) 'args': m.toolArgs,
              if (m.isTool && m.toolResult != null) 'result': m.toolResult,
              if (m.isTool && m.reviewed != null) 'reviewed': m.reviewed,
            }
        ],
      };

  String _encodeChat() => jsonEncode({
        ..._currentSession(),
        if (_archived.isNotEmpty) 'archived': _archived,
      });

  /// 每轮对话后自动持久化(已入库的事件)
  Future<void> _persistChat() async {
    final id = widget.event?.id;
    if (id == null) return;
    try {
      await widget.db.updateEvent(id, chatLog: _encodeChat());
    } catch (_) {}
  }

  @override
  void dispose() {
    AppContextRegistry.pop(_ctxProvider);
    _tab.dispose();
    _outlineCtrl.dispose();
    _contentCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        duration: Duration(seconds: error ? 6 : 3),
      ));
  }

  List<String> get _priorOutlines => [
        for (final e in widget.priorEvents)
          if (e.outline.trim().isNotEmpty) e.outline.trim()
      ];

  List<String> get _followingOutlines => [
        for (final e in widget.followingEvents)
          if (e.outline.trim().isNotEmpty) e.outline.trim()
      ];

  /// 前一个事件正文的结尾(衔接文风用)
  String get _prevTail {
    for (final e in widget.priorEvents.reversed) {
      final c = e.content.trim();
      if (c.isNotEmpty) {
        return c.length <= 300 ? c : c.substring(c.length - 300);
      }
    }
    return '';
  }

  /// 解析挂载令牌为卡片 id 集合(set:{id} 展开为集内全部卡)
  Set<int> _resolveMountTokens(String tokens, List<EntrySet> sets) {
    final ids = <int>{};
    for (final t in tokens.split(',')) {
      final tt = t.trim();
      if (tt.startsWith('set:')) {
        final sid = int.tryParse(tt.substring(4));
        for (final s in sets) {
          if (s.id == sid) {
            for (final e in s.entryIds.split(',')) {
              final id = int.tryParse(e.trim());
              if (id != null) ids.add(id);
            }
          }
        }
      } else {
        final id = int.tryParse(tt);
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  Future<void> _initSession() async {
    final all = await widget.db.allEntriesOf(widget.novel.id);
    final links = await widget.db.linksOfNovel(widget.novel.id);
    // 挂载的卡可能已被编辑,取库内最新状态
    final novel = await widget.db.novelById(widget.novel.id) ?? widget.novel;
    final sets = await widget.db.setsOf(widget.novel.id);
    final styleIds = _resolveMountTokens(novel.styleEntryIds, sets);
    final styles = [
      for (final e in all)
        if (styleIds.contains(e.id) && e.kind == EntryKind.lore.name) e
    ];
    _messages.add({
      'role': 'system',
      'content': writingAgentSystem(
        novel: novel,
        allEntries: all,
        links: links,
        chapterTitle: widget.chapter.title,
        priorOutlines: _priorOutlines,
        followingOutlines: _followingOutlines,
        prevContentTail: _prevTail,
        outline: _outlineCtrl.text,
        styleEntries: styles,
      ),
    });
  }

  /// 选择挂载到写作会话的设定卡/设定集(小说级,新对话生效)
  Future<void> _pickStyleEntries() async {
    final novel = await widget.db.novelById(widget.novel.id) ?? widget.novel;
    final all = await widget.db.allEntriesOf(widget.novel.id);
    var sets = await widget.db.setsOf(widget.novel.id);
    if (!mounted) return;
    final selected = <String>{
      for (final s in novel.styleEntryIds.split(','))
        if (s.trim().isNotEmpty) s.trim()
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('挂载设定'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选中的内容将全文常驻写作会话,作为最高优先级要求;新对话生效',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('设定集',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline)),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('新建'),
                              onPressed: () async {
                                final created =
                                    await _editSet(all, null);
                                if (created) {
                                  sets = await widget.db
                                      .setsOf(widget.novel.id);
                                  setDialog(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        if (sets.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('可把几张设定卡组合成集,一键整组挂载'),
                          ),
                        for (final s in sets)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.name),
                            subtitle: Text(
                                '含 ${s.entryIds.split(',').where((e) => e.trim().isNotEmpty).length} 张卡'),
                            secondary: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () async {
                                    final changed =
                                        await _editSet(all, s);
                                    if (changed) {
                                      sets = await widget.db
                                          .setsOf(widget.novel.id);
                                      setDialog(() {});
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  onPressed: () async {
                                    await widget.db.deleteSet(s.id);
                                    selected.remove('set:${s.id}');
                                    sets = await widget.db
                                        .setsOf(widget.novel.id);
                                    setDialog(() {});
                                  },
                                ),
                              ],
                            ),
                            value: selected.contains('set:${s.id}'),
                            onChanged: (v) => setDialog(() => v == true
                                ? selected.add('set:${s.id}')
                                : selected.remove('set:${s.id}')),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('单张设定卡',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline)),
                        ),
                        if (!all.any(
                            (e) => e.kind == EntryKind.lore.name))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('还没有设定类卡片;先在设定页建一张(如"文风""主线")'),
                          ),
                        for (final e in all)
                          if (e.kind == EntryKind.lore.name)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.name),
                              value: selected.contains('${e.id}'),
                              onChanged: (v) => setDialog(() => v == true
                                  ? selected.add('${e.id}')
                                  : selected.remove('${e.id}')),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.db.updateNovelStyle(
          widget.novel.id, selected.join(','));
      if (mounted) {
        setState(() {});
        _toast(selected.isEmpty
            ? '已清空挂载;开新对话生效'
            : '已挂载 ${selected.length} 项;开新对话生效');
      }
    }
  }

  /// 新建/编辑设定集;返回是否有变更
  Future<bool> _editSet(List<Entry> all, EntrySet? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final picked = <int>{
      if (editing != null)
        for (final s in editing.entryIds.split(','))
          ?int.tryParse(s.trim())
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(editing == null ? '新建设定集' : '编辑设定集'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: editing == null,
                  decoration: const InputDecoration(
                      labelText: '集名',
                      hintText: '如:核心风格 / 主线包',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in all)
                          if (e.kind == EntryKind.lore.name)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.name),
                              value: picked.contains(e.id),
                              onChanged: (v) => setDialog(() =>
                                  v == true
                                      ? picked.add(e.id)
                                      : picked.remove(e.id)),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(editing == null ? '创建' : '保存')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    if (ok != true || name.isEmpty) return false;
    if (editing == null) {
      await widget.db.createSet(widget.novel.id, name, picked.join(','));
    } else {
      await widget.db.updateSet(editing.id, name, picked.join(','));
    }
    return true;
  }

  /// 历史过长时压缩旧轮次为备忘。
  /// 阈值放宽以减少前缀缓存(KV cache)失效;切割点对齐到 user 消息,
  /// 避免 assistant(tool_calls) 与 tool 结果被拆散导致请求非法
  Future<void> _maybeCompress(LlmSettings settings) async {
    final histSize = _messages
        .skip(1)
        .fold<int>(0, (s, m) => s + (m['content']?.toString().length ?? 0));
    if (histSize < 60000 || _messages.length < 16) return;
    // 从后往前数第 4 条 user 消息作为保留区起点
    var keep = -1;
    var users = 0;
    for (var i = _messages.length - 1; i >= 1; i--) {
      if (_messages[i]['role'] == 'user') {
        users++;
        if (users == 4) {
          keep = i;
          break;
        }
      }
    }
    if (keep <= 1) return;
    final old = _messages.sublist(1, keep);
    final text = [
      for (final m in old)
        if (m['content'] != null && (m['role'] == 'user' || m['role'] == 'assistant'))
          '${m['role']}: ${m['content']}'
    ].join('\n');
    try {
      final summary = await LlmClient.chat(settings,
          system: compressChatSystem, user: text);
      _messages.removeRange(1, keep);
      _messages.insert(1, {
        'role': 'user',
        'content': '【此前对话备忘】\n$summary',
      });
    } catch (_) {
      // 压缩失败不阻断对话
    }
  }

  Future<void> _send() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    // 钉住的高亮优先;其次发送瞬间的实时选区
    var fullText = text;
    var uiText = text;
    String? selected;
    int? selStart;
    final hl = _contentCtrl.highlightedText;
    final sel = _effectiveSel;
    if (hl != null) {
      selected = hl;
      selStart = _contentCtrl.highlight!.start;
    } else if (sel != null) {
      final t = sel.textInside(_contentCtrl.text);
      if (t.trim().isNotEmpty) {
        selected = t;
        selStart = sel.start;
      }
    }
    if (selected != null && selStart != null) {
      final before = _contentCtrl.text.substring(0, selStart);
      final startLine = '\n'.allMatches(before).length + 1;
      final endLine = startLine + '\n'.allMatches(selected).length;
      final range = endLine == startLine ? '第 $startLine 行' : '第 $startLine-$endLine 行';
      fullText = '$text\n\n【作者高亮的正文片段($range)】\n$selected';
      uiText = '$text\n（附高亮片段 $range）';
    }
    setState(() {
      _busy = true;
      _stopRequested = false;
      // 新一轮开始:未处理的审批项视为接受
      for (final m in _chatUi) {
        if ((m.isChange || m.isTool) && m.reviewed == null) m.reviewed = true;
        m.revert = null;
      }
      _chatUi.add(_ChatMsg(true, uiText));
      _chatCtrl.clear();
    });
    _scrollChat();
    final snapshot =
        (outline: _outlineCtrl.text, content: _contentCtrl.text);
    final turnStart = _chatUi.length;
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.writing);
      // system 保持静态(仅新会话构建一次),前缀缓存友好;
      // 设定时效性由 agent 用检索工具自行保证
      if (_messages.isEmpty) {
        await _initSession();
      }
      await _maybeCompress(settings);
      _messages.add({'role': 'user', 'content': fullText});
      final executor = WritingToolExecutor(
        readContent: () => _contentCtrl.text,
        writeContent: (v) {
          if (!mounted) return;
          setState(() {
            _contentCtrl.text = v;
            _dirty = true;
          });
        },
        readOutline: () => _outlineCtrl.text,
        writeOutline: (v) {
          if (!mounted) return;
          setState(() {
            _outlineCtrl.text = v;
            _dirty = true;
          });
        },
        highlight: (frag) {
          if (frag.trim().isEmpty) {
            if (mounted) setState(() => _contentCtrl.clearHighlight());
            return '已清除高亮';
          }
          final c = _contentCtrl.text;
          final n = frag.allMatches(c).length;
          if (n == 0) return '失败:正文中未找到该片段,请先 read_content 核对';
          if (n > 1) return '失败:该片段出现 $n 处,请给更长的唯一片段';
          final idx = c.indexOf(frag);
          if (mounted) {
            setState(
                () => _contentCtrl.setHighlight(idx, idx + frag.length));
            if (_tab.index != 0) _toast('已在编辑页高亮标记');
          }
          final line = '\n'.allMatches(c.substring(0, idx)).length + 1;
          return '已高亮第 $line 行起的 ${frag.length} 字';
        },
        readHighlight: () {
          final h = _contentCtrl.highlight;
          return h == null || _contentCtrl.highlightedText == null
              ? null
              : (start: h.start, end: h.end);
        },
        db: widget.db,
        novelId: widget.novel.id,
        lookup: NovelToolExecutor(widget.db, widget.novel.id),
      );
      // 工具调用过程在对话流中可见(带参数详情与逆操作)
      Future<String> loggedCall(String name, Map<String, dynamic> args) async {
        final log = _ChatMsg.tool('', toolName: name, toolArgs: args);
        // 执行前捕获旧状态,构造分条回退
        Future<String?> Function()? revert;
        switch (name) {
          case 'replace_text':
            revert = () async {
              final oldT = args['old_text'] as String? ?? '';
              final newT = args['new_text'] as String? ?? '';
              if (oldT.isEmpty) return '无法回退';
              final c = _contentCtrl.text;
              if (newT.isEmpty || newT.allMatches(c).length != 1) {
                return '该处已被后续修改,无法单独回退';
              }
              setState(() {
                _contentCtrl.text = c.replaceFirst(newT, oldT);
                _dirty = true;
              });
              return null;
            };
          case 'append_text':
            revert = () async {
              final t = args['text'] as String? ?? '';
              final c = _contentCtrl.text;
              final idx = t.isEmpty ? -1 : c.lastIndexOf(t);
              if (idx < 0) return '该段已被修改,无法回退';
              setState(() {
                _contentCtrl.text =
                    (c.substring(0, idx) + c.substring(idx + t.length))
                        .trimRight();
                _dirty = true;
              });
              return null;
            };
          case 'set_content':
            final before = _contentCtrl.text;
            revert = () async {
              setState(() {
                _contentCtrl.text = before;
                _dirty = true;
              });
              return null;
            };
          case 'set_outline':
            final before = _outlineCtrl.text;
            revert = () async {
              setState(() {
                _outlineCtrl.text = before;
                _dirty = true;
              });
              return null;
            };
          case 'upsert_entry':
            final kind =
                EntryKind.values.asNameMap()[args['kind']?.toString()];
            final nm = args['name']?.toString().trim() ?? '';
            // 改名后按新名查找
            final renamed = args['fields'] is Map
                ? (args['fields'] as Map)['name']?.toString().trim()
                : null;
            final lookupName =
                (renamed?.isNotEmpty ?? false) ? renamed! : nm;
            Entry? before;
            if (kind != null && nm.isNotEmpty) {
              for (final e in await widget.db.allEntriesOf(widget.novel.id)) {
                if (e.kind == kind.name && e.name == nm) {
                  before = e;
                  break;
                }
              }
            }
            final beforeEntry = before;
            // 旧关联快照:回退时连同恢复
            final beforeLinks = beforeEntry == null
                ? const <({int toId, String label})>[]
                : [
                    for (final l in await widget.db.linksFrom(beforeEntry.id))
                      (toId: l.toEntryId, label: l.label)
                  ];
            revert = () async {
              if (kind == null || nm.isEmpty) return '无法回退';
              Entry? cur;
              for (final e in await widget.db.allEntriesOf(widget.novel.id)) {
                if (e.kind == kind.name && e.name == lookupName) {
                  cur = e;
                  break;
                }
              }
              if (beforeEntry == null) {
                if (cur != null) await widget.db.deleteEntry(cur.id);
              } else if (cur != null) {
                await widget.db.updateEntry(
                    cur.id, beforeEntry.name, beforeEntry.content);
                await widget.db.replaceLinksFrom(cur.id, beforeLinks);
              }
              return null;
            };
          case 'delete_entry':
            final kind =
                EntryKind.values.asNameMap()[args['kind']?.toString()];
            final nm = args['name']?.toString().trim() ?? '';
            Entry? victim;
            if (kind != null && nm.isNotEmpty) {
              for (final e in await widget.db.allEntriesOf(widget.novel.id)) {
                if (e.kind == kind.name && e.name == nm) {
                  victim = e;
                  break;
                }
              }
            }
            if (victim == null) break;
            // 删除前快照内容与双向关联,回退时重建
            final gone = victim;
            final outLinks = [
              for (final l in await widget.db.linksFrom(gone.id))
                (toId: l.toEntryId, label: l.label)
            ];
            final inLinks = [
              for (final l in await widget.db.linksTo(gone.id))
                (fromId: l.fromEntryId, label: l.label)
            ];
            revert = () async {
              final newId = await widget.db.createEntry(
                  widget.novel.id, kind!, gone.name, gone.content);
              await widget.db.replaceLinksFrom(newId, outLinks);
              for (final l in inLinks) {
                await widget.db.upsertLink(l.fromId, newId, l.label);
              }
              return null;
            };
        }
        if (mounted) setState(() => _chatUi.add(log));
        _scrollChat();
        final result = await executor.call(name, args);
        if (mounted) {
          setState(() {
            log.toolResult = result;
            // 执行失败的操作无需审批
            log.revert = result.startsWith('失败') ? null : revert;
          });
        }
        return result;
      }

      // 流式气泡:首个 delta 到达时加入,后续逐字增长
      _ChatMsg? streamMsg;
      void applyDelta(String d) {
        if (!mounted) return;
        setState(() {
          streamMsg ??= () {
            final m = _ChatMsg(false, '');
            _chatUi.add(m);
            return m;
          }();
          streamMsg!.text += d;
        });
        _scrollChat();
      }

      String reply;
      // 工具集固定不变:tools 序列化在前缀中,变化会打爆缓存
      final allTools = [...writingToolSchemas, ...novelToolSchemas];
      try {
        reply = await LlmClient.chatTurnStream(
          settings,
          messages: _messages,
          tools: allTools,
          onToolCall: loggedCall,
          onDelta: applyDelta,
          shouldStop: () => _stopRequested,
          onToolStart: (name) {
            if (!mounted) return;
            setState(() {
              // 工具轮之间新开气泡,避免后续文本接错位置
              streamMsg = null;
            });
          },
        );
      } on ToolsUnsupportedException {
        reply = await LlmClient.chatTurn(
          settings,
          messages: _messages,
          tools: allTools,
          onToolCall: loggedCall,
        );
      }
      if (!mounted) return;
      setState(() {
        // 用完整回复修正流式气泡(或补建)
        if (streamMsg != null) {
          streamMsg!.text = reply.trim();
        } else {
          _chatUi.add(_ChatMsg(false, reply.trim()));
        }
        // 回退栈仍保留轮级快照(undo 按钮兜底)
        final outlineChanged = snapshot.outline != _outlineCtrl.text;
        final contentChanged = snapshot.content != _contentCtrl.text;
        if (outlineChanged || contentChanged) {
          _history.add(snapshot);
          if (_history.length > 20) _history.removeAt(0);
        }
        // 回合末统一审批:收集本轮可回退的写操作
        final ops = [
          for (final m in _chatUi.skip(turnStart))
            if (m.isTool && m.revert != null && m.reviewed == null) m
        ];
        if (ops.isNotEmpty) _chatUi.add(_ChatMsg.review(ops));
      });
      // 在编辑页发的指令,给个简短回执(剔除思考块)
      if (_tab.index == 0) {
        final brief = reply
            .replaceAll(
                RegExp(r'<thinking>[\s\S]*?(?:</thinking>|$)'), '')
            .trim();
        _toast(brief.length <= 80 ? brief : '${brief.substring(0, 80)}…（详情见对话页）');
      }
      _scrollChat();
    } on LlmCancelledException {
      if (mounted) {
        setState(() => _chatUi.add(_ChatMsg.tool('⏹ 已停止')));
      }
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('对话失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _persistChat();
    }
  }

  /// 从正文整理大纲
  Future<void> _outlineFromContent() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _toast('正文还是空的,没法整理大纲', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.writing);
      final reply = await LlmClient.chat(settings,
          system: outlineFromContentSystem, user: content);
      if (!mounted) return;
      setState(() {
        _outlineCtrl.text = reply.trim();
        _dirty = true;
      });
      _toast('大纲已从正文整理');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('整理失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 回退到上一个快照
  void _undo() {
    if (_history.isEmpty) {
      _toast('没有可回退的版本', error: true);
      return;
    }
    final s = _history.removeLast();
    setState(() {
      _outlineCtrl.text = s.outline;
      _contentCtrl.text = s.content;
      _dirty = true;
    });
    _toast('已回退一步(剩 ${_history.length} 步可退)');
  }

  /// 正文的自定义选择菜单:复制/粘贴/全选/高亮/取消高亮
  Widget _contentContextMenu(BuildContext context, EditableTextState state) {
    final sel = _contentCtrl.selection;
    final hasSel = sel.isValid && !sel.isCollapsed;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        if (hasSel)
          ContextMenuButtonItem(
            label: '复制',
            onPressed: () =>
                state.copySelection(SelectionChangedCause.toolbar),
          ),
        ContextMenuButtonItem(
          label: '粘贴',
          onPressed: () => state.pasteText(SelectionChangedCause.toolbar),
        ),
        ContextMenuButtonItem(
          label: '全选',
          onPressed: () => state.selectAll(SelectionChangedCause.toolbar),
        ),
        if (hasSel)
          ContextMenuButtonItem(
            label: '高亮',
            onPressed: () {
              setState(() => _contentCtrl.setHighlight(sel.start, sel.end));
              state.hideToolbar();
            },
          ),
        if (_contentCtrl.highlight != null)
          ContextMenuButtonItem(
            label: '取消高亮',
            onPressed: () {
              setState(() => _contentCtrl.clearHighlight());
              state.hideToolbar();
            },
          ),
      ],
    );
  }

  /// 单击落在高亮内时,弹“取消高亮”菜单
  Future<void> _maybeOfferClearHighlight() async {
    final h = _contentCtrl.highlight;
    final sel = _contentCtrl.selection;
    if (h == null || !sel.isValid || !sel.isCollapsed) return;
    if (sel.start <= h.start || sel.start >= h.end) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final p = _lastTapPos;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(p.dx, p.dy, 0, 0), Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: 'clear', height: 40, child: Text('取消高亮')),
      ],
    );
    if (choice == 'clear' && mounted) {
      setState(() => _contentCtrl.clearHighlight());
    }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // reverse 列表的底部就是 offset 0,无需估算 maxScrollExtent
      if (_chatScroll.hasClients) _chatScroll.jumpTo(0);
    });
  }

  Future<void> _save() async {
    final outline = _outlineCtrl.text.trim();
    if (widget.event == null) {
      final id = await widget.db.createEvent(widget.chapter.id, outline);
      await widget.db.updateEvent(id,
          content: _contentCtrl.text, chatLog: _encodeChat());
    } else {
      await widget.db.updateEvent(widget.event!.id,
          outline: outline,
          content: _contentCtrl.text,
          chatLog: _encodeChat());
    }
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.event == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? '添加事件' : '编辑事件'),
          actions: [
            FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('保存')),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: '编辑', icon: Icon(Icons.edit_outlined)),
              Tab(text: '对话', icon: Icon(Icons.chat_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            // 编辑页:大纲 + 正文 + 底部对话输入(历史在对话页)
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    children: [
                TextField(
                  controller: _outlineCtrl,
                  minLines: 2,
                  maxLines: 6,
                  onChanged: (_) => _dirty = true,
                  decoration: InputDecoration(
                    labelText: '事件大纲',
                    hintText: '可手写,或写完正文后点右侧“整理”',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.sync_alt),
                      tooltip: '从正文整理大纲',
                      onPressed: _busy ? null : _outlineFromContent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Listener(
                  // 记录按下位置,供“取消高亮”弹出菜单定位
                  onPointerDown: (e) => _lastTapPos = e.position,
                  child: TextField(
                    controller: _contentCtrl,
                    minLines: 12,
                    maxLines: null,
                    onChanged: (_) => _dirty = true,
                    onTap: _maybeOfferClearHighlight,
                    contextMenuBuilder: _contentContextMenu,
                    decoration: const InputDecoration(
                      labelText: '正文(AI 在对话页直接修改这里)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentCtrl,
                        builder: (context, v, _) {
                          final lineCount = v.text.isEmpty
                              ? 0
                              : '\n'.allMatches(v.text).length + 1;
                          final s = v.selection;
                          final eff = _effectiveSel;
                          final selLen = eff != null
                              ? eff.textInside(v.text).length
                              : s.isValid && !s.isCollapsed
                                  ? s.textInside(v.text).length
                                  : 0;
                          final hl = _contentCtrl.highlightedText;
                          final info = hl != null
                              ? ' · 已高亮 ${hl.length} 字,对话将附带'
                              : selLen > 0
                                  ? ' · 已选中 $selLen 字'
                                  : '';
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$lineCount 行 · ${v.text.length} 字$info',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                ),
                              ),
                              if (hl == null && selLen > 0)
                                TextButton.icon(
                                  icon: const Icon(Icons.border_color,
                                      size: 16),
                                  label: const Text('标记高亮'),
                                  onPressed: () {
                                    final eff = _effectiveSel;
                                    if (eff == null) return;
                                    setState(() => _contentCtrl
                                        .setHighlight(eff.start, eff.end));
                                  },
                                )
                              else if (hl != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('清除高亮'),
                                  onPressed: () => setState(
                                      () => _contentCtrl.clearHighlight()),
                                ),
                              IconButton(
                                icon: const Icon(Icons.undo, size: 18),
                                tooltip: '回退上一版(${_history.length})',
                                onPressed:
                                    _history.isEmpty ? null : _undo,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 编辑页的快捷对话输入(不显示历史)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: Theme.of(context).dividerColor)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SubmitOnEnter(
                            onSubmit: _send,
                            child: TextField(
                              controller: _chatCtrl,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '快捷指令:Enter 发送,Shift+Enter 换行',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _busy
                              ? () => setState(() => _stopRequested = true)
                              : _send,
                          icon: Icon(_busy ? Icons.stop : Icons.send),
                          tooltip: _busy ? '停止' : '发送',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 对话页:全屏消息流 + 输入
            _chatTab(context),
          ],
        ),
      ),
    );
  }

  /// 变更卡:感知本轮改动,接受保留 / 拒绝回滚
  Widget _changeCard(BuildContext context, _ChatMsg m) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
              m.reviewed == false
                  ? Icons.replay
                  : m.reviewed == true
                      ? Icons.check_circle_outline
                      : Icons.edit_note,
              size: 18,
              color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              m.reviewed == false ? '${m.text}(已拒绝并回滚)' : m.text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (m.reviewed == null) ...[
            TextButton(
              onPressed: () {
                final s = m.snapshot;
                setState(() {
                  if (s != null) {
                    _outlineCtrl.text = s.outline;
                    _contentCtrl.text = s.content;
                    _history.remove(s);
                  }
                  m.reviewed = false;
                  _dirty = true;
                });
              },
              child: const Text('拒绝'),
            ),
            FilledButton.tonal(
              onPressed: () => setState(() => m.reviewed = true),
              child: const Text('接受'),
            ),
          ],
        ],
      ),
    );
  }

  /// 工具调用卡:摘要行(参数可见)+点击展开完整详情/diff
  Widget _toolCard(BuildContext context, _ChatMsg m) {
    final scheme = Theme.of(context).colorScheme;
    // 旧格式(仅文本)兼容显示
    if (m.toolName == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(m.text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline)),
      );
    }
    final name = m.toolName!;
    final args = m.toolArgs ?? const {};
    final result = m.toolResult;
    final running = result == null;
    final failed = result?.startsWith('失败') ?? false;
    final label = _toolLabels[name] ?? name;
    String s(Object? v, [int max = 24]) {
      final t = v?.toString().replaceAll('\n', ' ') ?? '';
      return t.length <= max ? t : '${t.substring(0, max)}…';
    }

    final summary = switch (name) {
      'replace_text' => '$label “${s(args['old_text'])}” → “${s(args['new_text'])}”',
      'append_text' => '$label +${(args['text']?.toString() ?? '').length} 字',
      'set_content' => '$label(${(args['text']?.toString() ?? '').length} 字)',
      'set_outline' => '$label “${s(args['text'])}”',
      'set_highlight' => '$label “${s(args['text'])}”',
      'upsert_entry' =>
        '$label「${args['name']}」(${[
          if (args['fields'] is Map) ...(args['fields'] as Map).keys,
          if (args['links'] is List) '关联×${(args['links'] as List).length}',
        ].join('、')})',
      'delete_entry' => '$label「${args['name']}」',
      'get_entry_detail' => '$label「${args['name']}」',
      _ => label,
    };
    final status = running
        ? '…'
        : failed
            ? ' ✗'
            : m.reviewed == false
                ? '(已回退)'
                : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => m.expanded = !m.expanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: failed
                ? scheme.errorContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      running
                          ? Icons.hourglass_top
                          : failed
                              ? Icons.error_outline
                              : m.reviewed == false
                                  ? Icons.replay
                                  : Icons.build_circle_outlined,
                      size: 14,
                      color: failed ? scheme.error : scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('$summary$status',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: failed ? scheme.error : scheme.outline,
                            decoration: m.reviewed == false
                                ? TextDecoration.lineThrough
                                : null)),
                  ),
                  Icon(m.expanded ? Icons.expand_less : Icons.expand_more,
                      size: 14, color: scheme.outline),
                ],
              ),
              if (m.expanded) ...[
                const SizedBox(height: 6),
                ..._toolDetail(context, name, args, result),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _toolDetail(BuildContext context, String name,
      Map<String, dynamic> args, String? result) {
    final scheme = Theme.of(context).colorScheme;
    Widget block(String text, {Color? bg, Color? fg}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: bg ?? scheme.surface,
              borderRadius: BorderRadius.circular(4)),
          child: SelectableText(text,
              style: TextStyle(fontSize: 12, height: 1.5, color: fg)),
        );
    final widgets = <Widget>[];
    switch (name) {
      case 'replace_text':
        widgets.add(block('- ${args['old_text'] ?? ''}',
            bg: Colors.red.withValues(alpha: 0.08), fg: Colors.red.shade700));
        widgets.add(block('+ ${args['new_text'] ?? ''}',
            bg: Colors.green.withValues(alpha: 0.08),
            fg: Colors.green.shade700));
      case 'append_text':
      case 'set_content':
      case 'set_outline':
        widgets.add(block('+ ${args['text'] ?? ''}',
            bg: Colors.green.withValues(alpha: 0.08),
            fg: Colors.green.shade700));
      case 'upsert_entry':
        final fields = args['fields'];
        if (fields is Map) {
          widgets.add(block([
            for (final e in fields.entries) '${e.key}: ${e.value}'
          ].join('\n')));
        }
        final lks = args['links'];
        if (lks is List && lks.isNotEmpty) {
          widgets.add(block([
            for (final r in lks)
              if (r is Map) '→ ${r['to']}${(r['label']?.toString() ?? '').isEmpty ? '' : ':${r['label']}'}'
          ].join('\n')));
        }
      default:
        if (args.isNotEmpty) {
          widgets.add(block(
              [for (final e in args.entries) '${e.key}: ${e.value}'].join('\n')));
        }
    }
    if (result != null) {
      widgets.add(block('结果:$result',
          fg: result.startsWith('失败') ? scheme.error : scheme.outline));
    }
    return widgets;
  }

  /// 回合末审批面板:分条拒绝/全部接受
  Widget _reviewPanel(BuildContext context, _ChatMsg panel) {
    final scheme = Theme.of(context).colorScheme;
    final ops = panel.ops ?? const <_ChatMsg>[];
    final pending = [for (final o in ops) if (o.reviewed == null) o];
    final done = pending.isEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.check_circle_outline : Icons.rule,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  done ? '本轮 ${ops.length} 项改动已处理' : '本轮 ${ops.length} 项改动,逐条确认:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (!done)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  onPressed: () async {
                    setState(() {
                      for (final o in pending) {
                        o.reviewed = true;
                      }
                    });
                    await _persistChat();
                  },
                  child: const Text('全部接受'),
                ),
            ],
          ),
          for (final o in ops)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _toolSummary(o),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                          decoration: o.reviewed == false
                              ? TextDecoration.lineThrough
                              : null),
                    ),
                  ),
                  if (o.reviewed == null) ...[
                    InkWell(
                      onTap: () async {
                        final err = await o.revert!();
                        if (!mounted) return;
                        if (err != null) {
                          _toast(err, error: true);
                        } else {
                          setState(() => o.reviewed = false);
                          await _persistChat();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('拒绝',
                            style: TextStyle(
                                fontSize: 12, color: scheme.error)),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        setState(() => o.reviewed = true);
                        await _persistChat();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('接受',
                            style: TextStyle(
                                fontSize: 12, color: scheme.primary)),
                      ),
                    ),
                  ] else if (o.reviewed == false)
                    Text('已回退',
                        style: TextStyle(fontSize: 12, color: scheme.error)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 工具操作的一句话摘要(审批面板复用)
  String _toolSummary(_ChatMsg m) {
    final name = m.toolName ?? '';
    final args = m.toolArgs ?? const {};
    final label = _toolLabels[name] ?? name;
    String s(Object? v, [int max = 20]) {
      final t = v?.toString().replaceAll('\n', ' ') ?? '';
      return t.length <= max ? t : '${t.substring(0, max)}…';
    }

    return switch (name) {
      'replace_text' => '$label “${s(args['old_text'])}” → “${s(args['new_text'])}”',
      'append_text' => '$label +${(args['text']?.toString() ?? '').length} 字',
      'set_content' => '$label(${(args['text']?.toString() ?? '').length} 字)',
      'set_outline' => '$label “${s(args['text'])}”',
      'set_highlight' => '$label “${s(args['text'])}”',
      'upsert_entry' => '$label「${args['name']}」',
      'delete_entry' => '$label「${args['name']}」',
      _ => label,
    };
  }

  /// 归档当前对话并开启新对话(system 重建,背景刷新)
  Future<void> _newChat() async {
    setState(() {
      _archiveCurrent();
    });
    await _persistChat();
    _toast('已开启新对话,历史可在右上角找回');
  }

  /// 把当前对话移入归档并清空(调用方负责 setState/persist)
  void _archiveCurrent() {
    if (_chatUi.isEmpty) return;
    // 未处理的审批项视为接受
    for (final m in _chatUi) {
      if ((m.isChange || m.isTool) && m.reviewed == null) m.reviewed = true;
      m.revert = null;
    }
    String title = '对话';
    for (final m in _chatUi) {
      if (m.isUser && m.text.trim().isNotEmpty) {
        final t = m.text.trim().split('\n').first;
        title = t.length <= 24 ? t : '${t.substring(0, 24)}…';
        break;
      }
    }
    _archived.add({
      'title': title,
      'at': DateTime.now().toIso8601String(),
      ..._currentSession(),
    });
    _messages.clear();
    _chatUi.clear();
  }

  /// 历史会话列表:恢复 / 删除
  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => ListView(
          shrinkWrap: true,
          children: [
            if (_archived.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('没有历史对话', textAlign: TextAlign.center),
              ),
            for (final (i, a) in _archived.indexed.toList().reversed)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(a['title']?.toString() ?? '对话'),
                subtitle: Text(
                    '${(a['at']?.toString() ?? '').replaceFirst('T', ' ').split('.').first}'
                    ' · ${(a['ui'] is List) ? (a['ui'] as List).length : 0} 条消息'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _resumeArchived(i);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: '删除这段历史',
                  onPressed: () async {
                    setSheet(() => _archived.removeAt(i));
                    setState(() {});
                    await _persistChat();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 恢复某段历史为当前对话;当前对话先归档
  Future<void> _resumeArchived(int index) async {
    final target = _archived[index];
    setState(() {
      _archived.removeAt(index);
      _archiveCurrent();
      _restoreCurrent(target);
    });
    await _persistChat();
    _scrollChat();
    _toast('已恢复历史对话');
  }

  /// 编辑历史用户消息并从该处重发:截断之后的上下文,正文改动不自动回退
  Future<void> _editAndResend(int uiIndex) async {
    final m = _chatUi[uiIndex];
    // 去掉展示用的附件后缀
    final base = m.text.split('\n（附高亮片段').first.split('\n（附选中片段').first;
    final ctrl = TextEditingController(text: base);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑并重发'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Text(
              '重发将丢弃此后的对话记录;已写入正文的改动不会自动回退,可用撤销按钮',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重发')),
        ],
      ),
    );
    final newText = ctrl.text.trim();
    if (ok != true || newText.isEmpty || _busy) return;
    // 定位 _messages 截断点:UI 中从该条起(含)的 user 数 = 从尾部往前第 k 条真实 user
    var k = 0;
    for (var i = uiIndex; i < _chatUi.length; i++) {
      if (_chatUi[i].isUser) k++;
    }
    var idx = -1, cnt = 0;
    for (var i = _messages.length - 1; i >= 1; i--) {
      final mm = _messages[i];
      if (mm['role'] == 'user' &&
          !(mm['content']?.toString().startsWith('【此前对话备忘】') ??
              false)) {
        cnt++;
        if (cnt == k) {
          idx = i;
          break;
        }
      }
    }
    if (idx < 0) {
      _toast('这条消息已被压缩进备忘,无法从此处重发', error: true);
      return;
    }
    setState(() {
      _messages.removeRange(idx, _messages.length);
      _chatUi.removeRange(uiIndex, _chatUi.length);
      // 截断前的待审批项视为接受
      for (final x in _chatUi) {
        if ((x.isTool || x.isChange) && x.reviewed == null) x.reviewed = true;
        x.revert = null;
      }
      _chatCtrl.text = newText;
    });
    await _persistChat();
    await _send();
  }

  /// AI 气泡内容:`<thinking>` 块折叠为思考卡,其余按 Markdown 渲染
  Widget _aiBody(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final reg = RegExp(r'<thinking>([\s\S]*?)(?:</thinking>|$)');
    final children = <Widget>[];
    var pos = 0;
    for (final match in reg.allMatches(text)) {
      final before = text.substring(pos, match.start).trim();
      if (before.isNotEmpty) {
        children.add(MarkdownBody(data: before, selectable: true));
      }
      final thinking = match.group(1)?.trim() ?? '';
      final closed = match.group(0)!.endsWith('</thinking>');
      if (thinking.isNotEmpty) {
        children.add(Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            dense: true,
            title: Text(closed ? '💭 思考过程' : '💭 思考中…',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline)),
            children: [
              SelectableText(thinking,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline, height: 1.5)),
            ],
          ),
        ));
      }
      pos = match.end;
    }
    final rest = text.substring(pos).trim();
    if (rest.isNotEmpty) {
      children.add(MarkdownBody(data: rest, selectable: true));
    }
    if (children.isEmpty) {
      return MarkdownBody(data: text, selectable: true);
    }
    if (children.length == 1) return children.first;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _chatTab(BuildContext context) {
    return Column(
      children: [
        // 会话管理条
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _archived.isEmpty
                      ? '当前对话'
                      : '当前对话 · 另有 ${_archived.length} 段历史',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.push_pin_outlined, size: 20),
                tooltip: '挂载设定',
                onPressed: _busy ? null : _pickStyleEntries,
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: '对话历史',
                onPressed:
                    _busy || _archived.isEmpty ? null : _showHistory,
              ),
              IconButton(
                icon: const Icon(Icons.add_comment_outlined, size: 20),
                tooltip: '新对话',
                onPressed: _busy || _chatUi.isEmpty ? null : _newChat,
              ),
            ],
          ),
        ),
        Expanded(
          child: _chatUi.isEmpty
              ? Center(
                  child: Text(
                    '与 AI 对话写作\n它会直接修改编辑页的正文与大纲',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  controller: _chatScroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _chatUi.length,
                  itemBuilder: (context, i) {
                    // reverse 列表:index 0 = 最新消息,天然贴底
                    final idx = _chatUi.length - 1 - i;
                    final m = _chatUi[idx];
                    if (m.isChange) return _changeCard(context, m);
                    if (m.isReview) return _reviewPanel(context, m);
                    if (m.isTool) return _toolCard(context, m);
                    final bubble = Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.sizeOf(context).width * 0.75),
                      decoration: BoxDecoration(
                        color: m.isUser
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: m.isUser
                          ? SelectableText(m.text)
                          : _aiBody(context, m.text),
                    );
                    if (!m.isUser) {
                      return Align(
                          alignment: Alignment.centerLeft, child: bubble);
                    }
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: '编辑并从这里重发',
                            visualDensity: VisualDensity.compact,
                            color: Theme.of(context).colorScheme.outline,
                            onPressed:
                                _busy ? null : () => _editAndResend(idx),
                          ),
                          Flexible(child: bubble),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SubmitOnEnter(
                    onSubmit: _send,
                    child: TextField(
                      controller: _chatCtrl,
                      focusNode: _chatFocus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '与 AI 对话写作:Enter 发送,Shift+Enter 换行',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy
                      ? () => setState(() => _stopRequested = true)
                      : _send,
                  icon: Icon(_busy ? Icons.stop : Icons.send),
                  tooltip: _busy ? '停止' : '发送',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
