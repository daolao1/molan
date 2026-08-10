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

/// 事件编辑:大纲 + 正文 + 对话式写作 agent
class EventEditPage extends StatefulWidget {
  const EventEditPage(
      {super.key,
      required this.db,
      required this.novel,
      required this.chapter,
      required this.priorEvents,
      this.event});

  final AppDatabase db;
  final Novel novel;
  final Chapter chapter;

  /// 本章中位于本事件之前的事件(供上下文)
  final List<ChapterEvent> priorEvents;
  final ChapterEvent? event;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _ChatMsg {
  _ChatMsg(this.isUser, this.text)
      : isChange = false,
        isTool = false,
        snapshot = null;

  _ChatMsg.change(this.text, this.snapshot)
      : isUser = false,
        isChange = true,
        isTool = false;

  _ChatMsg.tool(this.text, {this.toolName, this.toolArgs, this.toolResult})
      : isUser = false,
        isChange = false,
        isTool = true,
        snapshot = null;

  final bool isUser;
  String text;
  final bool isChange;
  final bool isTool;

  /// 工具调用详情(展开查看)
  String? toolName;
  Map<String, dynamic>? toolArgs;
  String? toolResult;
  bool expanded = false;

  /// 本轮改动前的快照(拒绝时恢复)
  final ({String outline, String content})? snapshot;

  /// null=待处理,true=已接受,false=已拒绝
  bool? reviewed;
}

class _EventEditPageState extends State<EventEditPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  late final _outlineCtrl =
      TextEditingController(text: widget.event?.outline ?? '');
  late final _contentCtrl =
      TextEditingController(text: widget.event?.content ?? '');
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

  static const _toolLabels = {
    'read_content': '读取正文',
    'replace_text': '修改文字',
    'append_text': '续写正文',
    'set_content': '重写全文',
    'read_outline': '读取大纲',
    'set_outline': '更新大纲',
    'upsert_entry': '更新设定',
    'get_entry_detail': '查阅设定',
    'list_entries': '列出条目',
    'get_relations': '查人物关系',
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
    _restoreChat();
  }

  /// 恢复持久化的对话;system 背景可能过期,下次发送前重建
  bool _systemStale = false;

  void _restoreChat() {
    final raw = widget.event?.chatLog ?? '';
    if (raw.trim().isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final msgs = data['messages'];
      if (msgs is List) {
        _messages.addAll([
          for (final m in msgs)
            if (m is Map) m.cast<String, dynamic>()
        ]);
        _systemStale = _messages.isNotEmpty;
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
              ));
            case 'change':
              _chatUi.add(_ChatMsg.change(text, null)
                ..reviewed = m['reviewed'] is bool ? m['reviewed'] as bool : true);
          }
        }
      }
    } catch (_) {
      // 损坏的历史不阻断页面
    }
  }

  String _encodeChat() => jsonEncode({
        'messages': _messages,
        'ui': [
          for (final m in _chatUi)
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
            }
        ],
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

  Future<void> _initSession() async {
    final all = await widget.db.allEntriesOf(widget.novel.id);
    final rels = await widget.db.relationsOfNovel(widget.novel.id);
    final links = await widget.db.linksOfNovel(widget.novel.id);
    _messages.add({
      'role': 'system',
      'content': writingAgentSystem(
        novel: widget.novel,
        allEntries: all,
        relations: rels,
        links: links,
        chapterTitle: widget.chapter.title,
        priorOutlines: _priorOutlines,
        prevContentTail: _prevTail,
        outline: _outlineCtrl.text,
      ),
    });
  }

  /// 历史过长时压缩旧轮次为备忘
  Future<void> _maybeCompress(LlmSettings settings) async {
    final histSize = _messages
        .skip(1)
        .fold<int>(0, (s, m) => s + (m['content']?.toString().length ?? 0));
    if (histSize < 16000 || _messages.length < 10) return;
    final keep = _messages.length - 4; // 保留最近几轮
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
    // 正文选区随消息附给 agent(发送瞬间快照)
    var fullText = text;
    var uiText = text;
    final sel = _contentCtrl.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final selected = sel.textInside(_contentCtrl.text);
      if (selected.trim().isNotEmpty) {
        final before = _contentCtrl.text.substring(0, sel.start);
        final startLine = '\n'.allMatches(before).length + 1;
        final endLine = startLine + '\n'.allMatches(selected).length;
        final range = endLine == startLine ? '第 $startLine 行' : '第 $startLine-$endLine 行';
        fullText = '$text\n\n【作者选中的正文片段($range)】\n$selected';
        uiText = '$text\n（附选中片段 $range）';
      }
    }
    setState(() {
      _busy = true;
      _stopRequested = false;
      // 新一轮开始:未处理的变更卡视为接受
      for (final m in _chatUi) {
        if (m.isChange && m.reviewed == null) m.reviewed = true;
      }
      _chatUi.add(_ChatMsg(true, uiText));
      _chatCtrl.clear();
    });
    _scrollChat();
    final snapshot =
        (outline: _outlineCtrl.text, content: _contentCtrl.text);
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.writing);
      if (_messages.isEmpty) {
        await _initSession();
      } else if (_systemStale) {
        // 重建背景,设定/前文可能已变化
        final all = await widget.db.allEntriesOf(widget.novel.id);
        final rels = await widget.db.relationsOfNovel(widget.novel.id);
        final links = await widget.db.linksOfNovel(widget.novel.id);
        final sys = {
          'role': 'system',
          'content': writingAgentSystem(
            novel: widget.novel,
            allEntries: all,
            relations: rels,
            links: links,
            chapterTitle: widget.chapter.title,
            priorOutlines: _priorOutlines,
            prevContentTail: _prevTail,
            outline: _outlineCtrl.text,
          ),
        };
        if (_messages.isNotEmpty && _messages.first['role'] == 'system') {
          _messages[0] = sys;
        } else {
          _messages.insert(0, sys);
        }
        _systemStale = false;
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
        db: widget.db,
        novelId: widget.novel.id,
        lookup: NovelToolExecutor(widget.db, widget.novel.id),
      );
      // 工具调用过程在对话流中可见(带参数详情)
      Future<String> loggedCall(String name, Map<String, dynamic> args) async {
        final log = _ChatMsg.tool('', toolName: name, toolArgs: args);
        if (mounted) setState(() => _chatUi.add(log));
        _scrollChat();
        final result = await executor.call(name, args);
        if (mounted) setState(() => log.toolResult = result);
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
      try {
        reply = await LlmClient.chatTurnStream(
          settings,
          messages: _messages,
          tools: [...writingToolSchemas, ...novelToolSchemas],
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
          tools: [...writingToolSchemas, ...novelToolSchemas],
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
        // 本轮有改动 → 压栈并插入变更卡
        final outlineChanged = snapshot.outline != _outlineCtrl.text;
        final contentChanged = snapshot.content != _contentCtrl.text;
        if (outlineChanged || contentChanged) {
          _history.add(snapshot);
          if (_history.length > 20) _history.removeAt(0);
          final delta = _contentCtrl.text.length - snapshot.content.length;
          final parts = [
            if (contentChanged)
              '正文${delta >= 0 ? '+' : ''}$delta 字',
            if (outlineChanged) '大纲已更新',
          ];
          _chatUi.add(_ChatMsg.change('本轮改动:${parts.join(' · ')}', snapshot));
        }
      });
      // 在编辑页发的指令,给个简短回执
      if (_tab.index == 0) {
        final brief = reply.trim();
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

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _save() async {
    final outline = _outlineCtrl.text.trim();
    if (outline.isEmpty && _contentCtrl.text.trim().isEmpty) {
      _toast('大纲与正文都为空,没有可保存的内容', error: true);
      return;
    }
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
                TextField(
                  controller: _contentCtrl,
                  minLines: 12,
                  maxLines: null,
                  onChanged: (_) => _dirty = true,
                  decoration: const InputDecoration(
                    labelText: '正文(AI 在对话页直接修改这里)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
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
                          final selLen = s.isValid && !s.isCollapsed
                              ? s.textInside(v.text).length
                              : 0;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$lineCount 行 · ${v.text.length} 字'
                                  '${selLen > 0 ? ' · 已选中 $selLen 字,对话将附带选区' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                ),
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
                          child: TextField(
                            controller: _chatCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: '快捷指令:改动直接落在正文,详情见对话页',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
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
      'upsert_entry' =>
        '$label「${args['name']}」(${args['fields'] is Map ? (args['fields'] as Map).keys.join('、') : ''})',
      'get_entry_detail' => '$label「${args['name']}」',
      _ => label,
    };
    final status = running
        ? '…'
        : failed
            ? ' ✗'
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
                              : Icons.build_circle_outlined,
                      size: 14,
                      color: failed ? scheme.error : scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('$summary$status',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: failed ? scheme.error : scheme.outline)),
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

  Widget _chatTab(BuildContext context) {
    return Column(
      children: [
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: _chatUi.length,
                  itemBuilder: (context, i) {
                    final m = _chatUi[i];
                    if (m.isChange) return _changeCard(context, m);
                    if (m.isTool) return _toolCard(context, m);
                    return Align(
                      alignment: m.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
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
                            : MarkdownBody(data: m.text, selectable: true),
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
                  child: TextField(
                    controller: _chatCtrl,
                    focusNode: _chatFocus,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '与 AI 对话写作:写一段/改一处/续写…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
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
