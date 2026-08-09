import 'package:shared_preferences/shared_preferences.dart';

/// 常见服务商预设,选中后自动填 Base URL 与默认模型
class LlmPreset {
  const LlmPreset(this.id, this.name, this.baseUrl, this.defaultModel,
      {this.keyUrl, this.needsKey = true});

  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String? keyUrl;
  final bool needsKey;
}

const llmPresets = [
  LlmPreset('deepseek', 'DeepSeek', 'https://api.deepseek.com/v1',
      'deepseek-chat',
      keyUrl: 'platform.deepseek.com'),
  LlmPreset('moonshot', 'Kimi (Moonshot)', 'https://api.moonshot.cn/v1',
      'moonshot-v1-8k',
      keyUrl: 'platform.moonshot.cn'),
  LlmPreset('zhipu', '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4',
      'glm-4-flash',
      keyUrl: 'open.bigmodel.cn'),
  LlmPreset('siliconflow', 'SiliconFlow', 'https://api.siliconflow.cn/v1',
      'Qwen/Qwen2.5-7B-Instruct',
      keyUrl: 'cloud.siliconflow.cn'),
  LlmPreset('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini',
      keyUrl: 'platform.openai.com'),
  LlmPreset('ollama', 'Ollama(本机)', 'http://localhost:11434/v1', 'llama3.1',
      needsKey: false),
  LlmPreset('custom', '自定义', '', ''),
];

class LlmSettings {
  const LlmSettings(
      {this.provider = 'deepseek',
      this.baseUrl = 'https://api.deepseek.com/v1',
      this.apiKey = '',
      this.model = 'deepseek-chat'});

  final String provider;
  final String baseUrl;
  final String apiKey;
  final String model;
}

class SettingsStore {
  static const _kProvider = 'llm_provider';
  static const _kBaseUrl = 'llm_base_url';
  static const _kApiKey = 'llm_api_key';
  static const _kModel = 'llm_model';

  static Future<LlmSettings> load() async {
    final p = await SharedPreferences.getInstance();
    const def = LlmSettings();
    return LlmSettings(
      provider: p.getString(_kProvider) ?? def.provider,
      baseUrl: p.getString(_kBaseUrl) ?? def.baseUrl,
      apiKey: p.getString(_kApiKey) ?? def.apiKey,
      model: p.getString(_kModel) ?? def.model,
    );
  }

  static Future<void> save(LlmSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProvider, s.provider);
    await p.setString(_kBaseUrl, s.baseUrl);
    await p.setString(_kApiKey, s.apiKey);
    await p.setString(_kModel, s.model);
  }
}
