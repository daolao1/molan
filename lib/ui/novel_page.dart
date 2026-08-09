import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';
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
  static const _kinds = EntryKind.values;
  late final TabController _tab =
      TabController(length: _kinds.length, vsync: this);

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
          novelId: widget.novel.id,
          kind: entry == null ? _currentKind : EntryKind.values.byName(entry.kind),
          entry: entry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
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
