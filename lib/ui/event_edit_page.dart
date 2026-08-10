import 'package:flutter/material.dart';

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
  _ChatMsg(this.isUser, this.text);
  final bool isUser;
  final String text;
}

class _EventEditPageState extends State<EventEditPage> {
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
  bool _busy = false;
  bool _dirty = false;

  PageSnapshot _ctxProvider() => PageSnapshot(
        novelId: widget.novel.id,
        detail: '正在编辑《${widget.novel.title}》章节《${widget.chapter.title}》的事件。\n'
            '事件大纲:${_outlineCtrl.text}\n当前正文:\n${_contentCtrl.text}',
      );

  @override
  void initState() {
    super.initState();
    AppContextRegistry.push(_ctxProvider);
  }

  @override
  void dispose() {
    AppContextRegistry.pop(_ctxProvider);
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
    setState(() {
      _busy = true;
      _chatUi.add(_ChatMsg(true, text));
      _chatCtrl.clear();
    });
    _scrollChat();
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.writing);
      if (_messages.isEmpty) await _initSession();
      await _maybeCompress(settings);
      _messages.add({'role': 'user', 'content': text});
      final executor = WritingToolExecutor(
        readContent: () => _contentCtrl.text,
        writeContent: (v) {
          if (!mounted) return;
          setState(() {
            _contentCtrl.text = v;
            _dirty = true;
          });
        },
        lookup: NovelToolExecutor(widget.db, widget.novel.id),
      );
      final reply = await LlmClient.chatTurn(
        settings,
        messages: _messages,
        tools: [...writingToolSchemas, ...novelToolSchemas],
        onToolCall: executor.call,
      );
      if (!mounted) return;
      setState(() => _chatUi.add(_ChatMsg(false, reply.trim())));
      _scrollChat();
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('对话失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
      await widget.db.updateEvent(id, content: _contentCtrl.text);
    } else {
      await widget.db.updateEvent(widget.event!.id,
          outline: outline, content: _contentCtrl.text);
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
        ),
        body: Column(
          children: [
            // 可滚动区:键盘弹出时正文不会被挤没,自动滚到光标
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
                      labelText: '正文(AI 通过对话直接修改这里)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            _chatPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel(BuildContext context) {
    // 键盘弹出且焦点不在对话输入时(在编正文),收起历史给正文腾地方
    final kbOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showHistory =
        _chatUi.isNotEmpty && (!kbOpen || _chatFocus.hasFocus);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHistory)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: narrow ? 140 : 200),
              child: ListView.builder(
                controller: _chatScroll,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                itemCount: _chatUi.length,
                itemBuilder: (context, i) {
                  final m = _chatUi[i];
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
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(m.text),
                    ),
                  );
                },
              ),
            ),
          Padding(
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
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
