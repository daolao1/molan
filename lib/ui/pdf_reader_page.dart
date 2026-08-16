import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-platform PDF viewer. PDFs remain binary documents instead of being
/// forced through the HTML/text chapter importer.
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key, required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final PdfController _controller;
  double _scale = 1;
  int _lastPage = 1;

  String get _stateKey =>
      'reader_pdf_state_${base64Url.encode(utf8.encode(widget.name))}';

  @override
  void initState() {
    super.initState();
    _controller = PdfController(document: PdfDocument.openData(widget.bytes));
    _restoreState();
  }

  @override
  void dispose() {
    _saveState();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final page = prefs.getInt('${_stateKey}_page');
    final scale = prefs.getDouble('${_stateKey}_scale');
    if (!mounted) return;
    setState(() {
      _lastPage = page?.clamp(1, 100000) ?? 1;
      _scale = scale?.clamp(.5, 3) ?? 1;
    });
    if (_lastPage > 1) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _controller.jumpToPage(_lastPage);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_stateKey}_page', _controller.page);
    await prefs.setDouble('${_stateKey}_scale', _scale);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name),
      actions: [
        IconButton(
          onPressed: () => setState(() => _scale = (_scale - .1).clamp(.5, 3)),
          icon: const Icon(Icons.zoom_out),
          tooltip: '缩小',
        ),
        Center(child: Text('${(_scale * 100).round()}%')),
        IconButton(
          onPressed: () => setState(() => _scale = (_scale + .1).clamp(.5, 3)),
          icon: const Icon(Icons.zoom_in),
          tooltip: '放大',
        ),
      ],
    ),
    body: PdfView(
      controller: _controller,
      onPageChanged: (page) {
        _lastPage = page;
        _saveState();
      },
      pageSnapping: false,
      physics: const BouncingScrollPhysics(),
      renderer: (page) => page.render(
        width: page.width * 2 * _scale,
        height: page.height * 2 * _scale,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      ),
      onDocumentError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF 打开失败：$error')));
      },
    ),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: _controller.pageListenable,
      builder: (context, page, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text('第 $page 页', textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}
