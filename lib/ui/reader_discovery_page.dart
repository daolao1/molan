import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/reader_web_client.dart';
import '../data/reader_web_models.dart';
import '../data/reader_web_sources.dart';
import 'reader_book_page.dart';

class ReaderDiscoveryPage extends StatefulWidget {
  const ReaderDiscoveryPage({super.key, required this.db});
  final AppDatabase db;
  @override
  State<ReaderDiscoveryPage> createState() => _ReaderDiscoveryPageState();
}

class _ReaderDiscoveryPageState extends State<ReaderDiscoveryPage> {
  final _query = TextEditingController();
  final _source = const PixivSource();
  late final PixivDiscovery _discovery = PixivDiscovery(_source);
  final _items = <DiscoveryItem>[];
  var _page = 1;
  var _hasMore = false;
  var _loading = false;
  Object? _error;
  String _mode = 'all';
  String _order = 'date_d';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool next = false}) async {
    if (_query.text.trim().isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!next) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final result = await _discovery.search(
        keyword: _query.text,
        page: _page,
        mode: _mode,
        order: _order,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import(DiscoveryItem item) async {
    try {
      final id = await ReaderWebClient.importUrl(widget.db, item.detailUrl);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderBookPage(db: widget.db, bookId: id),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('发现小说')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: '搜索 Pixiv 小说',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : () => _search(),
                icon: const Icon(Icons.search),
                tooltip: '搜索',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: '分级'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'safe', child: Text('全年龄')),
                    DropdownMenuItem(value: 'r18', child: Text('R-18')),
                  ],
                  onChanged: (v) => setState(() => _mode = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _order,
                  decoration: const InputDecoration(labelText: '排序'),
                  items: const [
                    DropdownMenuItem(value: 'date_d', child: Text('最新')),
                    DropdownMenuItem(value: 'date', child: Text('最早')),
                    DropdownMenuItem(value: 'popular_d', child: Text('热门')),
                  ],
                  onChanged: (v) => setState(() => _order = v ?? 'date_d'),
                ),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '搜索失败：$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _items.length)
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _page++;
                            _search(next: true);
                          },
                    icon: const Icon(Icons.expand_more),
                    label: const Text('加载更多'),
                  ),
                );
              final item = _items[index];
              return ListTile(
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (item.author?.isNotEmpty == true) item.author!,
                    if (item.tags.isNotEmpty) item.tags.take(4).join(' · '),
                    if (item.summary?.isNotEmpty == true) item.summary!,
                  ].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () => _import(item),
                  icon: const Icon(Icons.download_outlined),
                  tooltip: '导入阅读',
                ),
                onTap: () => _import(item),
              );
            },
          ),
        ),
      ],
    ),
  );
}
