import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/reader_import.dart';
import 'reader_book_page.dart';

class ReaderLibraryPage extends StatelessWidget {
  const ReaderLibraryPage({super.key, required this.db});
  final AppDatabase db;

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'html', 'htm', 'md', 'epub'],
    );
    if (result == null || result.files.single.bytes == null) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('阅读书库'),
      actions: [
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
