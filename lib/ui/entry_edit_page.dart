import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';

class EntryEditPage extends StatefulWidget {
  const EntryEditPage(
      {super.key,
      required this.db,
      required this.novelId,
      required this.kind,
      this.entry});

  final AppDatabase db;
  final int novelId;
  final EntryKind kind;
  final Entry? entry;

  @override
  State<EntryEditPage> createState() => _EntryEditPageState();
}

class _EntryEditPageState extends State<EntryEditPage> {
  late final _nameCtrl = TextEditingController(text: widget.entry?.name ?? '');
  late final List<EntryField> _fields = entryFieldsFor(widget.kind);
  late final Map<String, TextEditingController> _fieldCtrls;
  bool _dirty = false;

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
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    final content = encodeEntryContent(
        {for (final e in _fieldCtrls.entries) e.key: e.value.text});
    if (widget.entry == null) {
      await widget.db.createEntry(widget.novelId, widget.kind, name, content);
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
