import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/prompts.dart';
import '../data/settings.dart';

class EntryEditPage extends StatefulWidget {
  const EntryEditPage(
      {super.key,
      required this.db,
      required this.novel,
      required this.kind,
      this.entry});

  final AppDatabase db;
  final Novel novel;
  final EntryKind kind;
  final Entry? entry;

  @override
  State<EntryEditPage> createState() => _EntryEditPageState();
}

class _EntryEditPageState extends State<EntryEditPage> {
  late final _nameCtrl = TextEditingController(text: widget.entry?.name ?? '');
  final _aiPromptCtrl = TextEditingController();
  late final List<EntryField> _fields = entryFieldsFor(widget.kind);
  late final Map<String, TextEditingController> _fieldCtrls;
  bool _dirty = false;
  bool _generating = false;

  // 人物关系(仅 character):内存暂存,保存时同步入库
  List<Entry> _allCharacters = const [];
  final List<({int toId, String label})> _relations = [];
  List<CharacterRelation> _incoming = const [];

  @override
  void initState() {
    super.initState();
    final data = parseEntryContent(widget.entry?.content ?? '');
    _fieldCtrls = {
      for (final f in _fields)
        f.key: TextEditingController(text: data[f.key] ?? '')
    };
    if (widget.kind == EntryKind.character) _loadRelations();
  }

  Future<void> _loadRelations() async {
    final chars = await widget.db.charactersOf(widget.novel.id);
    final from = widget.entry == null
        ? <CharacterRelation>[]
        : await widget.db.relationsFrom(widget.entry!.id);
    final to = widget.entry == null
        ? <CharacterRelation>[]
        : await widget.db.relationsTo(widget.entry!.id);
    if (!mounted) return;
    setState(() {
      _allCharacters = chars;
      _relations
        ..clear()
        ..addAll([for (final r in from) (toId: r.toEntryId, label: r.label)]);
      _incoming = to;
    });
  }

  String _charName(int id) {
    for (final c in _allCharacters) {
      if (c.id == id) return c.name;
    }
    return '未知人物';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aiPromptCtrl.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    final request = _aiPromptCtrl.text.trim();
    if (request.isEmpty) {
      _toast('先用一句话描述你想要的${widget.kind.label}', error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final settings = await SettingsStore.load();
      final all = await widget.db.allEntriesOf(widget.novel.id);
      final rels = await widget.db.relationsOfNovel(widget.novel.id);
      // 卡片已有内容时走增量模式:只让模型返回需新增/修改的字段
      final incremental = _nameCtrl.text.trim().isNotEmpty ||
          _fieldCtrls.values.any((c) => c.text.trim().isNotEmpty);
      final reply = await LlmClient.chat(
        settings,
        system: entryGenerationSystem(widget.kind, incremental: incremental),
        user: entryGenerationUser(
          novel: widget.novel,
          kind: widget.kind,
          allEntries: all,
          relations: rels,
          currentName: _nameCtrl.text,
          currentData: {
            for (final e in _fieldCtrls.entries) e.key: e.value.text
          },
          request: request,
        ),
      );
      final data = LlmClient.parseJsonReply(reply);
      if (!mounted) return;
      setState(() {
        if ((data['name'] ?? '').isNotEmpty) _nameCtrl.text = data['name']!;
        for (final f in _fields) {
          if ((data[f.key] ?? '').isNotEmpty) {
            _fieldCtrls[f.key]!.text = data[f.key]!;
          }
        }
        _aiPromptCtrl.clear();
        _dirty = true;
      });
      _toast('已生成,请检查各字段并保存');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _addRelation() async {
    final others = [
      for (final c in _allCharacters)
        if (c.id != widget.entry?.id) c
    ];
    if (others.isEmpty) {
      _toast('本小说还没有其他人物,先去创建吧', error: true);
      return;
    }
    var targetId = others.first.id;
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加关系'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: targetId,
              decoration: const InputDecoration(
                  labelText: '目标人物', border: OutlineInputBorder()),
              items: [
                for (final c in others)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => targetId = v ?? targetId,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: '关系',
                  hintText: '师徒 / 宿敌 / 青梅竹马 / 暗恋…',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('添加')),
        ],
      ),
    );
    if (ok == true && labelCtrl.text.trim().isNotEmpty) {
      setState(() {
        _relations.add((toId: targetId, label: labelCtrl.text.trim()));
        _dirty = true;
      });
    }
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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('名称不能为空', error: true);
      return;
    }
    final content = encodeEntryContent(
        {for (final e in _fieldCtrls.entries) e.key: e.value.text});
    int entryId;
    if (widget.entry == null) {
      entryId = await widget.db
          .createEntry(widget.novel.id, widget.kind, name, content);
    } else {
      entryId = widget.entry!.id;
      await widget.db.updateEntry(entryId, name, content);
    }
    if (widget.kind == EntryKind.character) {
      await widget.db.replaceRelationsFrom(entryId, _relations);
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
    final isNew = widget.entry == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${isNew ? '新建' : '编辑'}${widget.kind.label}'),
          actions: [
            FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('保存')),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('AI 生成',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _aiPromptCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '一句话描述你想要的${widget.kind.label},'
                            '已填内容会作为参考一并融合',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_generating ? '生成中…' : '生成并填入'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: isNew,
              onChanged: (_) => _dirty = true,
              decoration: InputDecoration(
                  labelText: '${widget.kind.label}名称 *',
                  border: const OutlineInputBorder()),
            ),
            for (final f in _fields) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _fieldCtrls[f.key],
                maxLines: f.lines == 1 ? 1 : null,
                minLines: f.lines,
                onChanged: (_) => _dirty = true,
                decoration: InputDecoration(
                  labelText: f.label,
                  hintText: f.hint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (widget.kind == EntryKind.character) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('人物关系',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ),
                          TextButton.icon(
                            onPressed: _addRelation,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        ],
                      ),
                      if (_relations.isEmpty && _incoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('还没有关系,点右上角添加'),
                        ),
                      for (var i = 0; i < _relations.length; i++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.arrow_forward, size: 18),
                          title: Text(
                              '${_relations[i].label} → ${_charName(_relations[i].toId)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: '删除',
                            onPressed: () => setState(() {
                              _relations.removeAt(i);
                              _dirty = true;
                            }),
                          ),
                        ),
                      for (final r in _incoming)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.arrow_back, size: 18),
                          title: Text(
                              '${_charName(r.fromEntryId)} 的「${r.label}」'),
                          subtitle: const Text('由对方添加,在对方卡片中管理'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
