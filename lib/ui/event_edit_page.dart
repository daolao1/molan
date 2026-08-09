import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';

/// 事件编辑:大纲 + 正文,AI 按大纲生成/完善正文
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

class _EventEditPageState extends State<EventEditPage> {
  late final _outlineCtrl =
      TextEditingController(text: widget.event?.outline ?? '');
  late final _contentCtrl =
      TextEditingController(text: widget.event?.content ?? '');
  final _aiCtrl = TextEditingController();
  bool _generating = false;
  bool _dirty = false;

  @override
  void dispose() {
    _outlineCtrl.dispose();
    _contentCtrl.dispose();
    _aiCtrl.dispose();
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

  Future<({
    LlmSettings settings,
    List<Entry> all,
    List<CharacterRelation> rels,
    List<EntryLink> links
  })> _loadContext() async {
    final settings = await SettingsStore.load();
    final all = await widget.db.allEntriesOf(widget.novel.id);
    final rels = await widget.db.relationsOfNovel(widget.novel.id);
    final links = await widget.db.linksOfNovel(widget.novel.id);
    return (settings: settings, all: all, rels: rels, links: links);
  }

  List<String> get _priorOutlines => [
        for (final e in widget.priorEvents)
          if (e.outline.trim().isNotEmpty) e.outline.trim()
      ];

  Future<String> _chat(LlmSettings settings,
      {required String system, required String user}) async {
    try {
      return await LlmClient.chatWithTools(
        settings,
        system: system,
        user: user,
        tools: novelToolSchemas,
        onToolCall: NovelToolExecutor(widget.db, widget.novel.id).call,
      );
    } on ToolsUnsupportedException {
      return await LlmClient.chat(settings, system: system, user: user);
    }
  }

  /// 按指令生成/微调大纲
  Future<void> _generateOutline() async {
    final instruction = _aiCtrl.text.trim();
    if (instruction.isEmpty) {
      _toast('先在 AI 指令框写下想法,如:主角在雨夜遭伏,发现对方是故人', error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final ctx = await _loadContext();
      final reply = await _chat(
        ctx.settings,
        system: eventOutlineSystem(withTools: true),
        user: eventOutlineUser(
          novel: widget.novel,
          allEntries: ctx.all,
          relations: ctx.rels,
          links: ctx.links,
          chapterTitle: widget.chapter.title,
          priorOutlines: _priorOutlines,
          currentOutline: _outlineCtrl.text,
          instruction: instruction,
        ),
      );
      if (!mounted) return;
      setState(() {
        _outlineCtrl.text = reply.trim();
        _aiCtrl.clear();
        _dirty = true;
      });
      _toast('大纲已生成,可微调后再生成正文');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('生成失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// 按大纲(+可选指令)生成/微调正文
  Future<void> _generate() async {
    final outline = _outlineCtrl.text.trim();
    if (outline.isEmpty) {
      _toast('先写事件大纲,AI 才知道写什么', error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final ctx = await _loadContext();
      final reply = await _chat(
        ctx.settings,
        system: eventContentSystem(withTools: true),
        user: eventContentUser(
          novel: widget.novel,
          allEntries: ctx.all,
          relations: ctx.rels,
          links: ctx.links,
          chapterTitle: widget.chapter.title,
          priorOutlines: _priorOutlines,
          prevContentTail: _prevTail,
          outline: outline,
          currentContent: _contentCtrl.text,
          instruction: _aiCtrl.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        _contentCtrl.text = reply.trim();
        _aiCtrl.clear();
        _dirty = true;
      });
      _toast('正文已生成,可微调后保存');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('生成失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final outline = _outlineCtrl.text.trim();
    if (outline.isEmpty) {
      _toast('事件大纲不能为空', error: true);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _outlineCtrl,
                autofocus: isNew,
                minLines: 2,
                maxLines: 5,
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                  labelText: '事件大纲 *',
                  hintText: '这一段发生什么:谁、在哪、做了什么、结果如何',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _aiCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'AI 指令(可选)',
                  hintText: '写大纲:描述情节想法;改正文:如“把气氛写得更压抑”',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '指令驱动大纲;大纲(+指令)驱动正文',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _generating ? null : _generateOutline,
                    icon: const Icon(Icons.notes, size: 18),
                    label: const Text('写大纲'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_generating ? '生成中…' : '写正文'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _contentCtrl,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => _dirty = true,
                  decoration: const InputDecoration(
                    labelText: '正文',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
