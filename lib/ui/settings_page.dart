import 'package:flutter/material.dart';

import '../data/llm_client.dart';
import '../data/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  String _provider = 'deepseek';
  bool _showKey = false;
  bool _loaded = false;
  bool _busy = false;

  LlmPreset get _preset =>
      llmPresets.firstWhere((p) => p.id == _provider,
          orElse: () => llmPresets.last);

  LlmSettings get _current => LlmSettings(
        provider: _provider,
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
      );

  @override
  void initState() {
    super.initState();
    SettingsStore.load().then((s) {
      if (!mounted) return;
      setState(() {
        _provider = s.provider;
        _baseUrlCtrl.text = s.baseUrl;
        _apiKeyCtrl.text = s.apiKey;
        _modelCtrl.text = s.model;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String id) {
    final preset = llmPresets.firstWhere((p) => p.id == id);
    setState(() {
      _provider = id;
      if (preset.baseUrl.isNotEmpty) _baseUrlCtrl.text = preset.baseUrl;
      if (preset.defaultModel.isNotEmpty) {
        _modelCtrl.text = preset.defaultModel;
      }
    });
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? Theme.of(context).colorScheme.error : null,
        duration: Duration(seconds: error ? 6 : 3),
      ));
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickModel() => _run(() async {
        final models = await LlmClient.fetchModels(_current);
        if (!mounted) return;
        final picked = await _showModelPicker(models);
        if (picked != null) setState(() => _modelCtrl.text = picked);
      });

  Future<String?> _showModelPicker(List<String> models) {
    var filter = '';
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final shown = models
              .where((m) => m.toLowerCase().contains(filter.toLowerCase()))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                      hintText: '筛选 ${models.length} 个模型…',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder()),
                  onChanged: (v) => setSheetState(() => filter = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(shown[i]),
                    onTap: () => Navigator.pop(context, shown[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _test() => _run(() async {
        final ms = await LlmClient.testChat(_current);
        _toast('连接成功,模型响应正常(${ms}ms)');
      });

  Future<void> _save() async {
    if (_baseUrlCtrl.text.trim().isEmpty) {
      _toast('Base URL 不能为空', error: true);
      return;
    }
    await SettingsStore.save(_current);
    _toast('已保存');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('LLM API', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: llmPresets.any((p) => p.id == _provider)
                      ? _provider
                      : 'custom',
                  decoration: const InputDecoration(
                      labelText: '服务商', border: OutlineInputBorder()),
                  items: [
                    for (final p in llmPresets)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => v == null ? null : _applyPreset(v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.deepseek.com/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: !_showKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    helperText: !_preset.needsKey
                        ? '本机服务无需 Key'
                        : _preset.keyUrl != null
                            ? '在 ${_preset.keyUrl} 创建'
                            : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      tooltip: _showKey ? '隐藏' : '显示',
                      onPressed: () => setState(() => _showKey = !_showKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(
                    labelText: '模型',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.list_alt_outlined),
                      tooltip: '从服务商获取模型列表',
                      onPressed: _busy ? null : _pickModel,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.bolt_outlined),
                        label: const Text('测试连接'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
