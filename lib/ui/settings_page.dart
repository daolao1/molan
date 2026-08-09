import 'package:flutter/material.dart';

import '../data/llm_client.dart';
import '../data/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _ProfileCtrls {
  final baseUrl = TextEditingController();
  final apiKey = TextEditingController();
  final model = TextEditingController();
  String provider = 'deepseek';
  bool showKey = false;
  bool enabled = false;

  LlmSettings toSettings() => LlmSettings(
        provider: provider,
        baseUrl: baseUrl.text.trim(),
        apiKey: apiKey.text.trim(),
        model: model.text.trim(),
      );

  void fill(LlmSettings s) {
    provider = s.provider;
    baseUrl.text = s.baseUrl;
    apiKey.text = s.apiKey;
    model.text = s.model;
  }

  void dispose() {
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final _ctrls = {for (final p in LlmPurpose.values) p: _ProfileCtrls()};
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final p in LlmPurpose.values) {
      _ctrls[p]!.fill(await SettingsStore.loadProfile(p));
      _ctrls[p]!.enabled = await SettingsStore.profileEnabled(p);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
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

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickModel(_ProfileCtrls c) => _run(() async {
        final models = await LlmClient.fetchModels(c.toSettings());
        if (!mounted) return;
        final picked = await _showModelPicker(models);
        if (picked != null) setState(() => c.model.text = picked);
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

  Future<void> _test(_ProfileCtrls c) => _run(() async {
        final ms = await LlmClient.testChat(c.toSettings());
        _toast('连接成功,模型响应正常(${ms}ms)');
      });

  Future<void> _save() async {
    if (_ctrls[LlmPurpose.main]!.baseUrl.text.trim().isEmpty) {
      _toast('主 API 的 Base URL 不能为空', error: true);
      return;
    }
    for (final p in LlmPurpose.values) {
      await SettingsStore.saveProfile(p, _ctrls[p]!.toSettings());
      if (p != LlmPurpose.main) {
        await SettingsStore.setProfileEnabled(p, _ctrls[p]!.enabled);
      }
    }
    _toast('已保存');
  }

  List<Widget> _profileForm(_ProfileCtrls c) {
    final preset = llmPresets.firstWhere((p) => p.id == c.provider,
        orElse: () => llmPresets.last);
    return [
      DropdownButtonFormField<String>(
        initialValue:
            llmPresets.any((p) => p.id == c.provider) ? c.provider : 'custom',
        decoration: const InputDecoration(
            labelText: '服务商', border: OutlineInputBorder()),
        items: [
          for (final p in llmPresets)
            DropdownMenuItem(value: p.id, child: Text(p.name)),
        ],
        onChanged: (v) {
          if (v == null) return;
          final preset = llmPresets.firstWhere((p) => p.id == v);
          setState(() {
            c.provider = v;
            if (preset.baseUrl.isNotEmpty) c.baseUrl.text = preset.baseUrl;
            if (preset.defaultModel.isNotEmpty) {
              c.model.text = preset.defaultModel;
            }
          });
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: c.baseUrl,
        decoration: const InputDecoration(
            labelText: 'Base URL', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: c.apiKey,
        obscureText: !c.showKey,
        decoration: InputDecoration(
          labelText: 'API Key',
          helperText: !preset.needsKey
              ? '本机服务无需 Key'
              : preset.keyUrl != null
                  ? '在 ${preset.keyUrl} 创建'
                  : null,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(c.showKey
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => c.showKey = !c.showKey),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: c.model,
        decoration: InputDecoration(
          labelText: '模型',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: '从服务商获取模型列表',
            onPressed: _busy ? null : () => _pickModel(c),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _test(c),
          icon: const Icon(Icons.bolt_outlined, size: 18),
          label: const Text('测试连接'),
        ),
      ),
    ];
  }

  Widget _subProfileCard(LlmPurpose purpose, String subtitle) {
    final c = _ctrls[purpose]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('单独配置${purpose.label}'),
              subtitle: Text(c.enabled ? subtitle : '关闭时使用主 API'),
              value: c.enabled,
              onChanged: (v) => setState(() => c.enabled = v),
            ),
            if (c.enabled) ...[
              const SizedBox(height: 4),
              ..._profileForm(c),
            ],
          ],
        ),
      ),
    );
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('主 API(默认所有功能使用)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        ..._profileForm(_ctrls[LlmPurpose.main]!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _subProfileCard(LlmPurpose.lore, '设定卡与世界观生成使用此配置'),
                const SizedBox(height: 8),
                _subProfileCard(LlmPurpose.writing, '大纲与正文生成使用此配置'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存全部'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
