import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';
import 'entry_edit_page.dart';

class NovelPage extends StatefulWidget {
  const NovelPage({super.key, required this.db, required this.novel});

  final AppDatabase db;
  final Novel novel;

  @override
  State<NovelPage> createState() => _NovelPageState();
}

class _NovelPageState extends State<NovelPage>
    with SingleTickerProviderStateMixin {
  // 场景挂在地点下,不作为顶层 tab
  static const _kinds = [
    EntryKind.character,
    EntryKind.location,
    EntryKind.item,
    EntryKind.lore,
  ];
  late final TabController _tab =
      TabController(length: _kinds.length, vsync: this);
  bool _bulkGenerating = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  EntryKind get _currentKind => _kinds[_tab.index];

  void _openEditor({Entry? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditPage(
          db: widget.db,
          novel: widget.novel,
          kind: entry == null ? _currentKind : EntryKind.values.byName(entry.kind),
          entry: entry,
        ),
      ),
    );
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

  /// 一个提示词批量生成多条设定
  Future<void> _bulkGenerateLore() async {
    final promptCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 批量生成设定'),
        content: TextField(
          controller: promptCtrl,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '例:修真等级体系、三大门派及恩怨、灵石货币体系…\n一条要求可生成多条设定',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('生成')),
        ],
      ),
    );
    final request = promptCtrl.text.trim();
    if (ok != true || request.isEmpty) return;
    setState(() => _bulkGenerating = true);
    try {
      final settings = await SettingsStore.load();
      final all = await widget.db.allEntriesOf(widget.novel.id);
      final rels = await widget.db.relationsOfNovel(widget.novel.id);
      final links = await widget.db.linksOfNovel(widget.novel.id);
      final userMsg = loreGenerationUser(
          novel: widget.novel,
          allEntries: all,
          relations: rels,
          links: links,
          request: request);
      String reply;
      try {
        reply = await LlmClient.chatWithTools(
          settings,
          system: loreGenerationSystem(withTools: true),
          user: userMsg,
          tools: novelToolSchemas,
          onToolCall: NovelToolExecutor(widget.db, widget.novel.id).call,
        );
      } on ToolsUnsupportedException {
        reply = await LlmClient.chat(settings,
            system: loreGenerationSystem(), user: userMsg);
      }
      final items = [
        for (final m in LlmClient.parseJsonArrayReply(reply))
          (
            name: m['name']?.toString().trim() ?? '',
            detail: m['detail']?.toString().trim() ?? '',
          )
      ].where((it) => it.name.isNotEmpty && it.detail.isNotEmpty).toList();
      if (items.isEmpty) throw LlmException('未生成有效条目,请重试');
      if (!mounted) return;
      final accept = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('生成了 ${items.length} 条设定'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) => ListTile(
                dense: true,
                title: Text(items[i].name),
                subtitle: Text(items[i].detail,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('放弃')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('全部添加')),
          ],
        ),
      );
      if (accept == true) {
        final nameToId = {for (final e in all) e.name: e.id};
        var linked = 0;
        for (final m in LlmClient.parseJsonArrayReply(reply)) {
          final name = m['name']?.toString().trim() ?? '';
          final detail = m['detail']?.toString().trim() ?? '';
          if (name.isEmpty || detail.isEmpty) continue;
          final id = await widget.db.createEntry(widget.novel.id,
              EntryKind.lore, name, encodeEntryContent({'detail': detail}));
          final related = m['related'];
          if (related is List) {
            final toIds = <int>[];
            for (final r in related) {
              final target = nameToId[r?.toString().trim()];
              if (target != null && !toIds.contains(target)) {
                toIds.add(target);
                linked++;
              }
            }
            if (toIds.isNotEmpty) {
              await widget.db.replaceLinksFrom(id, toIds);
            }
          }
        }
        _toast(linked > 0
            ? '已添加 ${items.length} 条设定(含 $linked 条关联)'
            : '已添加 ${items.length} 条设定');
      }
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _bulkGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
        actions: [
          AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => _currentKind == EntryKind.lore
                ? IconButton(
                    icon: _bulkGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    tooltip: 'AI 批量生成设定',
                    onPressed: _bulkGenerating ? null : _bulkGenerateLore,
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final k in _kinds) Tab(text: k.label, icon: Icon(k.icon))],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          for (final kind in _kinds)
            _EntryList(
                db: widget.db,
                novelId: widget.novel.id,
                kind: kind,
                onTapEntry: (e) => _openEditor(entry: e)),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: Text('新建${_currentKind.label}'),
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList(
      {required this.db,
      required this.novelId,
      required this.kind,
      required this.onTapEntry});

  final AppDatabase db;
  final int novelId;
  final EntryKind kind;
  final void Function(Entry) onTapEntry;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: db.watchEntries(novelId, kind),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(child: Text('还没有${kind.label},点右下角新建'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final e = items[i];
            final subtitle = entrySubtitle(e);
            return Card(
              child: ListTile(
                leading: Icon(kind.icon),
                title: Text(e.name),
                subtitle: subtitle.isEmpty
                    ? null
                    : Text(subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') await db.deleteEntry(e.id);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
                onTap: () => onTapEntry(e),
              ),
            );
          },
        );
      },
    );
  }
}
