import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/reader_import.dart';
import '../data/reader_web_client.dart';
import 'reader_book_page.dart';
import 'reader_discovery_page.dart';
import 'pdf_reader_page.dart';

class ReaderLibraryPage extends StatelessWidget {
  const ReaderLibraryPage({super.key, required this.db});
  final AppDatabase db;

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'html', 'htm', 'md', 'epub', 'pdf'],
    );
    if (result == null || result.files.single.bytes == null) return;
    if (result.files.single.name.toLowerCase().endsWith('.pdf')) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfReaderPage(
            name: result.files.single.name,
            bytes: result.files.single.bytes!,
          ),
        ),
      );
      return;
    }
    try {
      final id = await ReaderImport.importBytes(
        db,
        result.files.single.name,
        result.files.single.bytes!,
      );
      if (context.mounted)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderBookPage(db: db, bookId: id),
          ),
        );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _importUrl(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入网页书籍'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '小说 URL',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('抓取'),
          ),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      final id = await ReaderWebClient.importUrl(db, controller.text.trim());
      if (context.mounted)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderBookPage(db: db, bookId: id),
          ),
        );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网页导入失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('阅读书库'),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReaderDiscoveryPage(db: db)),
          ),
          icon: const Icon(Icons.explore_outlined),
          tooltip: '发现小说',
        ),
        IconButton(
          onPressed: () => _importUrl(context),
          icon: const Icon(Icons.language_outlined),
          tooltip: '导入网页',
        ),
        IconButton(
          onPressed: () => _import(context),
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: '导入书籍',
        ),
      ],
    ),
    body: StreamBuilder<List<ReaderBook>>(
      stream: db.watchReaderBooks(),
      builder: (context, snap) {
        final books = snap.data ?? const [];
        if (books.isEmpty)
          return const Center(child: Text('书库为空，请导入 TXT、HTML 或 EPUB'));
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (_, i) => ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(books[i].title),
            subtitle: Text(books[i].author.isEmpty ? '本地书籍' : books[i].author),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReaderBookPage(db: db, bookId: books[i].id),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => db.deleteReaderBook(books[i].id),
            ),
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _import(context),
      icon: const Icon(Icons.add),
      label: const Text('导入书籍'),
    ),
  );
}
