import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/settings.dart';
import '../data/style_extract.dart';
import 'widgets.dart';

/// 文风萃取:导入 txt/epub 材料 → 逐维度分析 → 生成设定卡组成设定集
class StyleExtractView extends StatefulWidget {
  const StyleExtractView({super.key, required this.db, required this.novel});

  final AppDatabase db;
  final Novel novel;

  @override
  State<StyleExtractView> createState() => _StyleExtractViewState();
}

class _StyleExtractViewState extends State<StyleExtractView> {
  final _setNameCtrl = TextEditingController();
  String _material = '';
  String _sourceName = '';
  bool _busy = false;
  int _progress = 0;

  /// 萃取结果:(维度名, 规范正文)
  final List<(String, String)> _results = [];

  @override
  void dispose() {
    _setNameCtrl.dispose();
    super.dispose();
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

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'epub'],
      withData: true,
    );
    final f = res?.files.single;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;
    String text;
    try {
      if (f.name.toLowerCase().endsWith('.epub')) {
        text = extractEpubText(bytes);
      } else {
        text = String.fromCharCodes(bytes);
        // txt 常见 UTF-8;严格解一次,失败则保留 latin1 先行结果
        try {
          text = utf8.decode(bytes);
        } catch (_) {}
      }
    } catch (e) {
      _toast('解析失败:$e', error: true);
      return;
    }
    if (text.trim().length < 500) {
      _toast('材料太短(不足 500 字),不足以分析文风', error: true);
      return;
    }
    setState(() {
      _material = text;
      _sourceName = f.name;
      _results.clear();
      if (_setNameCtrl.text.trim().isEmpty) {
        _setNameCtrl.text =
            '文风·${f.name.replaceAll(RegExp(r'\.(txt|epub)$', caseSensitive: false), '')}';
      }
    });
  }

  /// 直接粘贴文本作为材料
  Future<void> _pasteText() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴材料'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: '粘贴一段喜欢的作品正文(至少 500 字)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true) return;
    if (text.length < 500) {
      _toast('材料太短(不足 500 字),不足以分析文风', error: true);
      return;
    }
    setState(() {
      _material = text;
      _sourceName = '粘贴的文本';
      _results.clear();
      if (_setNameCtrl.text.trim().isEmpty) {
        _setNameCtrl.text = '文风·未命名';
      }
    });
  }

  Future<void> _extract() async {
    if (_material.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _results.clear();
    });
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.lore);
      final sample = sampleMaterial(_material);
      for (final (i, dim) in styleDimensions.indexed) {
        if (!mounted) return;
        setState(() => _progress = i + 1);
        final reply = await LlmClient.chat(settings,
            system: styleExtractSystem(dim.$1, dim.$2),
            user: '【材料】\n$sample');
        final detail =
            LlmClient.parseJsonReply(reply)['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty && mounted) {
          setState(() => _results.add((dim.$1, detail)));
        }
      }
      if (_results.isEmpty) throw LlmException('未能萃取出有效内容,请重试');
      _toast('萃取完成,检查结果后入库');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('萃取失败:$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAll() async {
    final setName = _setNameCtrl.text.trim();
    if (setName.isEmpty || _results.isEmpty) return;
    // 卡名只用维度名,不混入集名;重名自动加序号
    final existing = {
      for (final e in await widget.db.allEntriesOf(widget.novel.id))
        if (e.kind == EntryKind.lore.name) e.name
    };
    String unique(String base) {
      if (!existing.contains(base)) return base;
      var i = 2;
      while (existing.contains('$base $i')) {
        i++;
      }
      return '$base $i';
    }

    final ids = <int>[];
    for (final (dim, detail) in _results) {
      final name = unique(dim);
      existing.add(name);
      final id = await widget.db.createEntry(widget.novel.id, EntryKind.lore,
          name, encodeEntryContent({'detail': detail}));
      ids.add(id);
    }
    await widget.db.createSet(widget.novel.id, setName, ids.join(','));
    if (mounted) {
      setState(() => _results.clear());
      _toast('已生成设定集「$setName」(${ids.length} 张卡);去写作页"挂载设定"整组启用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('文风萃取', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '导入一段喜欢的作品(txt / epub),AI 从七个维度萃取其写作风格,'
                  '生成一组风格规范卡并打包成设定集;在写作页挂载后,agent 将按该文风写作。',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('导入文件'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pasteText,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('粘贴文本'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _material.isEmpty
                            ? '未导入'
                            : '$_sourceName · ${_material.length} 字'
                                '${_material.length > 24000 ? '(将采样约 2.4 万字)' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SubmitOnEnter(
                  onSubmit: _busy ? () {} : _extract,
                  child: TextField(
                    controller: _setNameCtrl,
                    decoration: const InputDecoration(
                      labelText: '设定集名称',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed:
                          _busy || _material.isEmpty ? null : _extract,
                      icon: _busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.onPrimary))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_busy
                          ? '萃取中 $_progress/${styleDimensions.length}'
                          : '开始萃取'),
                    ),
                    const SizedBox(width: 12),
                    if (_results.isNotEmpty && !_busy)
                      FilledButton.tonalIcon(
                        onPressed: _saveAll,
                        icon: const Icon(Icons.save_alt),
                        label: Text('入库(${_results.length} 张卡)'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final (dim, detail) in _results)
          Card(
            child: ExpansionTile(
              title: Text(dim),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                SelectableText(detail,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.6)),
              ],
            ),
          ),
      ],
    );
  }
}
