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

/// LLM 配置组用途:主 API 兜底,子 API 按功能域覆盖
enum LlmPurpose {
  main('llm', '主 API'),
  lore('llm_lore', '设定 API'),
  writing('llm_writing', '写作 API'),
  image('llm_image', '生图 API');

  const LlmPurpose(this.prefix, this.label);
  final String prefix;
  final String label;
}

class SettingsStore {
  static LlmSettings _read(SharedPreferences p, String prefix) {
    const def = LlmSettings();
    return LlmSettings(
      provider: p.getString('${prefix}_provider') ?? def.provider,
      baseUrl: p.getString('${prefix}_base_url') ?? def.baseUrl,
      apiKey: p.getString('${prefix}_api_key') ?? def.apiKey,
      model: p.getString('${prefix}_model') ?? def.model,
    );
  }

  /// 读取某组的原始配置(不回退)
  static Future<LlmSettings> loadProfile(LlmPurpose purpose) async {
    final p = await SharedPreferences.getInstance();
    return _read(p, purpose.prefix);
  }

  /// 子 API 是否启用(主 API 恒启用)
  static Future<bool> profileEnabled(LlmPurpose purpose) async {
    if (purpose == LlmPurpose.main) return true;
    final p = await SharedPreferences.getInstance();
    return p.getBool('${purpose.prefix}_enabled') ?? false;
  }

  /// 按用途取生效配置:子 API 未启用时回退主 API
  static Future<LlmSettings> loadFor(LlmPurpose purpose) async {
    final p = await SharedPreferences.getInstance();
    if (purpose != LlmPurpose.main &&
        (p.getBool('${purpose.prefix}_enabled') ?? false)) {
      return _read(p, purpose.prefix);
    }
    return _read(p, LlmPurpose.main.prefix);
  }

  static Future<void> saveProfile(LlmPurpose purpose, LlmSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${purpose.prefix}_provider', s.provider);
    await p.setString('${purpose.prefix}_base_url', s.baseUrl);
    await p.setString('${purpose.prefix}_api_key', s.apiKey);
    await p.setString('${purpose.prefix}_model', s.model);
  }

  static Future<void> setProfileEnabled(LlmPurpose purpose, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('${purpose.prefix}_enabled', v);
  }

  /// 兼容旧调用:主 API
  static Future<LlmSettings> load() => loadFor(LlmPurpose.main);
}
