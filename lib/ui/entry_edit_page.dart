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

  @override
  void initState() {
    super.initState();
    final data = parseEntryContent(widget.entry?.content ?? '');
    _fieldCtrls = {
      for (final f in _fields)
        f.key: TextEditingController(text: data[f.key] ?? '')
    };
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
      final names = await widget.db.entryNames(widget.novel.id, widget.kind);
      final reply = await LlmClient.chat(
        settings,
        system: entryGenerationSystem(widget.kind),
        user: entryGenerationUser(
          novel: widget.novel,
          kind: widget.kind,
          existingNames: names,
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
    if (widget.entry == null) {
      await widget.db
          .createEntry(widget.novel.id, widget.kind, name, content);
    } else {
      await widget.db.updateEntry(widget.entry!.id, name, content);
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
