import 'package:flutter/material.dart';

import '../data/db.dart';

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
  late final _contentCtrl =
      TextEditingController(text: widget.entry?.content ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    final content = _contentCtrl.text;
    if (widget.entry == null) {
      await widget.db.createEntry(widget.novelId, widget.kind, name, content);
    } else {
      await widget.db.updateEntry(widget.entry!.id, name, content);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry == null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${isNew ? '新建' : '编辑'}${widget.kind.label}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.check), tooltip: '保存', onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: isNew,
              decoration: InputDecoration(
                  labelText: '${widget.kind.label}名称',
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                    labelText: '设定描述',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
