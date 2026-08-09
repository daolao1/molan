import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';

class EntryEditPage extends StatefulWidget {
  const EntryEditPage(
      {super.key,
      required this.db,
      required this.novel,
      required this.kind,
      this.entry,
      this.parentId});

  final AppDatabase db;
  final Novel novel;
  final EntryKind kind;
  final Entry? entry;

  /// 场景所属地点的条目 id
  final int? parentId;

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
  late GenerationMode _genMode = widget.entry == null
      ? GenerationMode.generate
      : GenerationMode.supplement;

  /// 生成前快照;非 null 表示等待接受/拒绝
  ({
    String name,
    Map<String, String> fields,
    List<({int toId, String label})> relations
  })? _snapshot;

  // 人物关系(仅 character):内存暂存,保存时同步入库
  List<Entry> _allCharacters = const [];
  final List<({int toId, String label})> _relations = [];
  List<CharacterRelation> _incoming = const [];

  // 设定关联(仅 lore):内存暂存,保存时同步入库
  List<Entry> _allEntries = const [];
  final List<int> _links = [];

  @override
  void initState() {
    super.initState();
    final data = parseEntryContent(widget.entry?.content ?? '');
    _fieldCtrls = {
      for (final f in _fields)
        f.key: TextEditingController(text: data[f.key] ?? '')
    };
    if (widget.kind == EntryKind.character) _loadRelations();
    if (widget.kind == EntryKind.lore) _loadLinks();
  }

  Future<void> _loadLinks() async {
    final all = await widget.db.allEntriesOf(widget.novel.id);
    final links = widget.entry == null
        ? <EntryLink>[]
        : await widget.db.linksFrom(widget.entry!.id);
    if (!mounted) return;
    setState(() {
      _allEntries = all;
      _links
        ..clear()
        ..addAll([for (final l in links) l.toEntryId]);
    });
  }

  Entry? _entryById(int id) {
    for (final e in _allEntries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _addLink() async {
    final candidates = [
      for (final e in _allEntries)
        if (e.id != widget.entry?.id && !_links.contains(e.id)) e
    ];
    if (candidates.isEmpty) {
      _toast('没有可关联的卡片了', error: true);
      return;
    }
    var targetId = candidates.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关联卡片'),
        content: DropdownButtonFormField<int>(
          initialValue: targetId,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: '选择卡片', border: OutlineInputBorder()),
          items: [
            for (final e in candidates)
              DropdownMenuItem(
                  value: e.id,
                  child: Text(
                      '[${EntryKind.values.byName(e.kind).label}] ${e.name}',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => targetId = v ?? targetId,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('关联')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _links.add(targetId);
        _dirty = true;
      });
    }
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
      final links = await widget.db.linksOfNovel(widget.novel.id);
      final userMsg = entryGenerationUser(
        novel: widget.novel,
        kind: widget.kind,
        allEntries: all,
        relations: rels,
        links: links,
        currentName: _nameCtrl.text,
        currentData: {
          for (final e in _fieldCtrls.entries) e.key: e.value.text
        },
        request: request,
        parentLocation: widget.parentId == null
            ? null
            : all
                .where((e) => e.id == widget.parentId)
                .map((e) => e.name)
                .firstOrNull,
      );
      String reply;
      try {
        // Agentic 检索:模型可自主调工具查详情;不支持则回退全量注入
        final executor = NovelToolExecutor(widget.db, widget.novel.id);
        reply = await LlmClient.chatWithTools(
          settings,
          system: entryGenerationSystem(widget.kind,
              mode: _genMode, withTools: true),
          user: userMsg,
          tools: novelToolSchemas,
          onToolCall: executor.call,
        );
      } on ToolsUnsupportedException {
        reply = await LlmClient.chat(
          settings,
          system: entryGenerationSystem(widget.kind, mode: _genMode),
          user: userMsg,
        );
      }
      final data = LlmClient.parseJsonReply(reply);
      if (!mounted) return;
      String? textOf(String key) {
        final v = data[key];
        return v == null || v is List || v is Map ? null : v.toString();
      }

      // 先存快照供拒绝时回滚
      final snapshot = (
        name: _nameCtrl.text,
        fields: {for (final e in _fieldCtrls.entries) e.key: e.value.text},
        relations: List.of(_relations),
      );
      var addedRels = 0;
      setState(() {
        _snapshot = snapshot;
        final name = textOf('name') ?? '';
        if (name.isNotEmpty) _nameCtrl.text = name;
        for (final f in _fields) {
          final v = textOf(f.key) ?? '';
          if (v.isNotEmpty) _fieldCtrls[f.key]!.text = v;
        }
        // AI 返回的关系:按名字匹配已有人物,失配/重复的丢弃
        final rels = data['relations'];
        if (widget.kind == EntryKind.character && rels is List) {
          for (final r in rels) {
            if (r is! Map) continue;
            final target = r['target']?.toString().trim() ?? '';
            final label = r['label']?.toString().trim() ?? '';
            if (target.isEmpty || label.isEmpty) continue;
            for (final c in _allCharacters) {
              if (c.name == target && c.id != widget.entry?.id) {
                final dup = _relations
                    .any((x) => x.toId == c.id && x.label == label);
                if (!dup) {
                  _relations.add((toId: c.id, label: label));
                  addedRels++;
                }
                break;
              }
            }
          }
        }
        // AI 返回的关联卡片(仅 lore):按名字匹配
        final related = data['related'];
        if (widget.kind == EntryKind.lore && related is List) {
          for (final r in related) {
            final name = r?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            for (final e in _allEntries) {
              if (e.name == name && e.id != widget.entry?.id) {
                if (!_links.contains(e.id)) {
                  _links.add(e.id);
                  addedRels++;
                }
                break;
              }
            }
          }
        }
        _aiPromptCtrl.clear();
        _dirty = true;
      });
      _toast(addedRels > 0
          ? '已生成(含 $addedRels 条关联),请检查后接受或拒绝'
          : '已生成,请检查后接受或拒绝');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('生成失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// index 为 null 时新增,否则编辑第 index 条关系
  Future<void> _editRelation({int? index}) async {
    final others = [
      for (final c in _allCharacters)
        if (c.id != widget.entry?.id) c
    ];
    if (others.isEmpty) {
      _toast('本小说还没有其他人物,先去创建吧', error: true);
      return;
    }
    final editing = index != null ? _relations[index] : null;
    var targetId = editing?.toId ?? others.first.id;
    if (!others.any((c) => c.id == targetId)) targetId = others.first.id;
    final labelCtrl = TextEditingController(text: editing?.label ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing == null ? '添加关系' : '编辑关系'),
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
              autofocus: editing == null,
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
              child: Text(editing == null ? '添加' : '保存')),
        ],
      ),
    );
    if (ok == true && labelCtrl.text.trim().isNotEmpty) {
      setState(() {
        final rel = (toId: targetId, label: labelCtrl.text.trim());
        if (index == null) {
          _relations.add(rel);
        } else {
          _relations[index] = rel;
        }
        _dirty = true;
      });
    }
  }

  void _acceptGeneration() {
    setState(() => _snapshot = null);
    _toast('已接受,记得保存');
  }

  void _rejectGeneration() {
    final s = _snapshot;
    if (s == null) return;
    setState(() {
      _nameCtrl.text = s.name;
      for (final e in s.fields.entries) {
        _fieldCtrls[e.key]?.text = e.value;
      }
      _relations
        ..clear()
        ..addAll(s.relations);
      _snapshot = null;
    });
    _toast('已恢复生成前的内容');
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
      entryId = await widget.db.createEntry(
          widget.novel.id, widget.kind, name, content,
          parentId: widget.parentId);
    } else {
      entryId = widget.entry!.id;
      await widget.db.updateEntry(entryId, name, content);
    }
    if (widget.kind == EntryKind.character) {
      await widget.db.replaceRelationsFrom(entryId, _relations);
    }
    if (widget.kind == EntryKind.lore) {
      await widget.db.replaceLinksFrom(entryId, _links);
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
            // 设定的 AI 生成在列表页顶部统一提供,编辑页不重复显示
            if (widget.kind != EntryKind.lore)
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
                        hintText: _genMode == GenerationMode.generate
                            ? '一句话描述你想要的${widget.kind.label},AI 自由发挥填满整卡'
                            : '写下要补充的设定,AI 只更新相关字段,其余不动',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_snapshot != null)
                      Row(
                        children: [
                          const Expanded(
                              child: Text('对生成结果满意吗？拒绝将恢复之前内容')),
                          OutlinedButton.icon(
                            onPressed: _rejectGeneration,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('拒绝'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _acceptGeneration,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('接受'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          SegmentedButton<GenerationMode>(
                            segments: [
                              for (final m in GenerationMode.values)
                                ButtonSegment(
                                    value: m,
                                    label: Text(m.label),
                                    tooltip: m == GenerationMode.generate
                                        ? '自由发挥,填满整张卡片'
                                        : '只写你提到的内容,其他字段不动'),
                            ],
                            selected: {_genMode},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) =>
                                setState(() => _genMode = s.first),
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: _generating ? null : _generate,
                            icon: _generating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.auto_awesome),
                            label: Text(_generating
                                ? '生成中…'
                                : '${_genMode.label}并填入'),
                          ),
                        ],
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
                            onPressed: () => _editRelation(),
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
                          onTap: () => _editRelation(index: i),
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
            if (widget.kind == EntryKind.location && widget.entry != null) ...[
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
                            child: Text('本地点的场景',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EntryEditPage(
                                  db: widget.db,
                                  novel: widget.novel,
                                  kind: EntryKind.scene,
                                  parentId: widget.entry!.id,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加场景'),
                          ),
                        ],
                      ),
                      StreamBuilder<List<Entry>>(
                        stream: widget.db.watchScenesOf(widget.entry!.id),
                        builder: (context, snapshot) {
                          final scenes = snapshot.data ?? const [];
                          if (scenes.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('还没有场景,点右上角添加'),
                            );
                          }
                          return Column(
                            children: [
                              for (final s in scenes)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(EntryKind.scene.icon,
                                      size: 18),
                                  title: Text(s.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    tooltip: '删除',
                                    onPressed: () =>
                                        widget.db.deleteEntry(s.id),
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EntryEditPage(
                                        db: widget.db,
                                        novel: widget.novel,
                                        kind: EntryKind.scene,
                                        entry: s,
                                        parentId: widget.entry!.id,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.kind == EntryKind.lore) ...[
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
                            child: Text('关联卡片',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ),
                          TextButton.icon(
                            onPressed: _addLink,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        ],
                      ),
                      if (_links.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('可关联人物、地点、物品、场景或其他设定'),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final id in _links)
                            if (_entryById(id) case final e?)
                              InputChip(
                                avatar: Icon(
                                    EntryKind.values.byName(e.kind).icon,
                                    size: 16),
                                label: Text(e.name),
                                onDeleted: () => setState(() {
                                  _links.remove(id);
                                  _dirty = true;
                                }),
                              ),
                        ],
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
