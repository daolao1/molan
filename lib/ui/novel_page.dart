import 'package:flutter/material.dart';

import '../data/app_context.dart';
import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';
import 'chapters_page.dart';
import 'entry_edit_page.dart';
import 'reading_view.dart';
import 'widgets.dart';

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
  final _lorePromptCtrl = TextEditingController();

  /// 0 = 设定,1 = 写作,2 = 阅读
  int _section = 0;

  PageSnapshot _ctxProvider() => PageSnapshot(
        novelId: widget.novel.id,
        detail:
            '正在浏览《${widget.novel.title}》的${['设定', '写作', '阅读'][_section]}区',
      );

  @override
  void initState() {
    super.initState();
    AppContextRegistry.push(_ctxProvider);
  }

  @override
  void dispose() {
    AppContextRegistry.pop(_ctxProvider);
    _tab.dispose();
    _lorePromptCtrl.dispose();
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

  /// 一个提示词批量生成多条设定(输入来自列表顶部生成框)
  Future<void> _bulkGenerateLore() async {
    if (_bulkGenerating) return;
    final request = _lorePromptCtrl.text.trim();
    if (request.isEmpty) {
      _toast('先描述要生成的设定,如:修真等级体系、三大门派及恩怨', error: true);
      return;
    }
    setState(() => _bulkGenerating = true);
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.lore);
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
        _lorePromptCtrl.clear();
      }
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('生成失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _bulkGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const names = ['设定', '写作', '阅读'];
    // 窄屏(手机)用底部导航,宽屏用右侧栏
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final content = switch (_section) {
      1 => ChaptersView(db: widget.db, novel: widget.novel),
      2 => ReadingView(db: widget.db, novel: widget.novel),
      _ => TabBarView(
          controller: _tab,
          children: [
            for (final kind in _kinds)
              _EntryList(
                  db: widget.db,
                  novelId: widget.novel.id,
                  kind: kind,
                  header:
                      kind == EntryKind.lore ? _loreGeneratorCard() : null,
                  onTapEntry: (e) => _openEditor(entry: e)),
          ],
        ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.novel.title} · ${names[_section]}'),
        bottom: _section != 0
            ? null
            : TabBar(
                controller: _tab,
                tabs: [
                  for (final k in _kinds) Tab(text: k.label, icon: Icon(k.icon))
                ],
              ),
      ),
      body: narrow
          ? content
          : Row(
              children: [
                Expanded(child: content),
                const VerticalDivider(width: 1),
                NavigationRail(
                  selectedIndex: _section,
                  onDestinationSelected: (i) => setState(() => _section = i),
                  labelType: NavigationRailLabelType.all,
                  minWidth: 64,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.category_outlined),
                        selectedIcon: Icon(Icons.category),
                        label: Text('设定')),
                    NavigationRailDestination(
                        icon: Icon(Icons.edit_note_outlined),
                        selectedIcon: Icon(Icons.edit_note),
                        label: Text('写作')),
                    NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('阅读')),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: !narrow
          ? null
          : NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (i) => setState(() => _section = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category),
                    label: '设定'),
                NavigationDestination(
                    icon: Icon(Icons.edit_note_outlined),
                    selectedIcon: Icon(Icons.edit_note),
                    label: '写作'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '阅读'),
              ],
            ),
      floatingActionButton: switch (_section) {
        1 => FloatingActionButton.extended(
            onPressed: () =>
                showChapterDialog(context, widget.db, widget.novel),
            icon: const Icon(Icons.add),
            label: const Text('新建章节'),
          ),
        2 => null,
        _ => AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text('新建${_currentKind.label}'),
            ),
          ),
      },
    );
  }

  Widget _loreGeneratorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text('AI 生成设定', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            SubmitOnEnter(
              onSubmit: _bulkGenerateLore,
              child: TextField(
                controller: _lorePromptCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '例:修真等级体系、三大门派及恩怨、灵石货币…Enter 生成',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _bulkGenerating ? null : _bulkGenerateLore,
                icon: _bulkGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_bulkGenerating ? '生成中…' : '生成'),
              ),
            ),
          ],
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
      required this.onTapEntry,
      this.header});

  final AppDatabase db;
  final int novelId;
  final EntryKind kind;
  final void Function(Entry) onTapEntry;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: db.watchEntries(novelId, kind),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length + (header == null ? 0 : 1) + (items.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            var i = index;
            if (header != null) {
              if (i == 0) return header!;
              i--;
            }
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('还没有${kind.label},点右下角新建')),
              );
            }
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
