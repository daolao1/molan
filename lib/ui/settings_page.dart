import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data/llm_client.dart';
import '../data/settings.dart';
import '../data/st_chatu8.dart';
import '../data/reader_preferences.dart';

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
  final _pixivCookie = TextEditingController();
  final _translationLanguage = TextEditingController();
  final _translationStyle = TextEditingController();
  ReaderPreferences _readerPreferences = const ReaderPreferences();

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
    _pixivCookie.text = await ReaderPreferencesStore.loadPixivCookie();
    _readerPreferences = await ReaderPreferencesStore.load();
    _translationLanguage.text = _readerPreferences.translationLanguage;
    _translationStyle.text = _readerPreferences.translationStyle;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _pixivCookie.dispose();
    _translationLanguage.dispose();
    _translationStyle.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
          duration: Duration(seconds: error ? 6 : 3),
        ),
      );
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
                    border: const OutlineInputBorder(),
                  ),
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
    await ReaderPreferencesStore.savePixivCookie(_pixivCookie.text);
    await ReaderPreferencesStore.save(
      _readerPreferences.copyWith(
        translationLanguage: _translationLanguage.text.trim().isEmpty
            ? '简体中文'
            : _translationLanguage.text.trim(),
        translationStyle: _translationStyle.text.trim(),
      ),
    );
    _toast('已保存');
  }

  Future<void> _importStChatu8() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    try {
      final config = StChatu8Store.parseImport(utf8.decode(bytes));
      await StChatu8Store.save(config);
      _toast('已导入 st-chat8 生图配置(${config.backend})');
    } catch (e) {
      _toast('st-chat8 配置导入失败：$e', error: true);
    }
  }

  List<Widget> _profileForm(_ProfileCtrls c) {
    final preset = llmPresets.firstWhere(
      (p) => p.id == c.provider,
      orElse: () => llmPresets.last,
    );
    return [
      DropdownButtonFormField<String>(
        initialValue: llmPresets.any((p) => p.id == c.provider)
            ? c.provider
            : 'custom',
        decoration: const InputDecoration(
          labelText: '服务商',
          border: OutlineInputBorder(),
        ),
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
          labelText: 'Base URL',
          border: OutlineInputBorder(),
        ),
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
            icon: Icon(
              c.showKey
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
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
            if (c.enabled) ...[const SizedBox(height: 4), ..._profileForm(c)],
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
                        Text(
                          '主 API(默认所有功能使用)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                const SizedBox(height: 8),
                _subProfileCard(
                  LlmPurpose.image,
                  '设定卡配图生成使用此配置。支持:OpenAI(dall-e-3/gpt-image-1)、Gemini(Base URL 填 https://generativelanguage.googleapis.com/v1beta/openai,模型如 gemini-2.5-flash-image)、SiliconFlow(Kwai-Kolors/Kolors)、NovelAI(Base URL 填 https://image.novelai.net,Key 用 pst- 持久令牌,模型如 nai-diffusion-4-5-full)',
                ),
                const SizedBox(height: 8),
                _readerPreferencesCard(),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.extension_outlined),
                    title: const Text('st-chat8 原生生图配置'),
                    subtitle: const Text(
                      '导入 st-chat8 导出的 JSON，支持 NovelAI 与 ComfyUI 工作流',
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: _importStChatu8,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('导入'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _pixivCookie,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Pixiv PHPSESSID（可选）',
                        helperText: '用于 R-18、系列目录和需要登录的 Pixiv 小说',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
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

  Widget _readerPreferencesCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('阅读与翻译', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _translationLanguage,
            decoration: const InputDecoration(
              labelText: '翻译目标语言',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _translationStyle,
            decoration: const InputDecoration(
              labelText: '翻译风格（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TranslationMode>(
            initialValue: _readerPreferences.translationMode,
            decoration: const InputDecoration(labelText: '默认显示模式'),
            items: const [
              DropdownMenuItem(
                value: TranslationMode.original,
                child: Text('原文'),
              ),
              DropdownMenuItem(
                value: TranslationMode.translated,
                child: Text('译文'),
              ),
              DropdownMenuItem(
                value: TranslationMode.bilingual,
                child: Text('双语'),
              ),
            ],
            onChanged: (v) => setState(() {
              if (v != null)
                _readerPreferences = _readerPreferences.copyWith(
                  translationMode: v,
                );
            }),
          ),
          DropdownButtonFormField<ReadingTheme>(
            initialValue: _readerPreferences.readingTheme,
            decoration: const InputDecoration(labelText: '阅读主题'),
            items: const [
              DropdownMenuItem(value: ReadingTheme.day, child: Text('日间')),
              DropdownMenuItem(value: ReadingTheme.sepia, child: Text('纸张')),
              DropdownMenuItem(value: ReadingTheme.night, child: Text('夜间')),
            ],
            onChanged: (v) => setState(() {
              if (v != null)
                _readerPreferences = _readerPreferences.copyWith(
                  readingTheme: v,
                );
            }),
          ),
          DropdownButtonFormField<ReaderFontFamily>(
            initialValue: _readerPreferences.readerFontFamily,
            decoration: const InputDecoration(labelText: '正文字体'),
            items: const [
              DropdownMenuItem(
                value: ReaderFontFamily.system,
                child: Text('默认'),
              ),
              DropdownMenuItem(
                value: ReaderFontFamily.serif,
                child: Text('衬线'),
              ),
              DropdownMenuItem(
                value: ReaderFontFamily.sansSerif,
                child: Text('无衬线'),
              ),
              DropdownMenuItem(
                value: ReaderFontFamily.monospace,
                child: Text('等宽'),
              ),
            ],
            onChanged: (v) => setState(() {
              if (v != null)
                _readerPreferences = _readerPreferences.copyWith(
                  readerFontFamily: v,
                );
            }),
          ),
          const SizedBox(height: 8),
          Text('网页预取：${_readerPreferences.prefetchAhead} 章'),
          Slider(
            value: _readerPreferences.prefetchAhead.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            onChanged: (v) => setState(
              () => _readerPreferences = _readerPreferences.copyWith(
                prefetchAhead: v.round(),
              ),
            ),
          ),
          Text('翻译批大小：${_readerPreferences.translationBatchChars} 字符'),
          Slider(
            value: _readerPreferences.translationBatchChars.toDouble(),
            min: 500,
            max: 12000,
            divisions: 23,
            onChanged: (v) => setState(
              () => _readerPreferences = _readerPreferences.copyWith(
                translationBatchChars: v.round(),
              ),
            ),
          ),
          Text('术语表上限：${_readerPreferences.glossaryMaxSize} 条'),
          Slider(
            value: _readerPreferences.glossaryMaxSize.toDouble().clamp(10, 500),
            min: 10,
            max: 500,
            divisions: 49,
            onChanged: (v) => setState(
              () => _readerPreferences = _readerPreferences.copyWith(
                glossaryMaxSize: v.round(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
