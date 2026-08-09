import 'package:shared_preferences/shared_preferences.dart';

class LlmSettings {
  const LlmSettings(
      {this.baseUrl = 'https://api.openai.com/v1',
      this.apiKey = '',
      this.model = 'gpt-4o-mini'});

  final String baseUrl;
  final String apiKey;
  final String model;
}

class SettingsStore {
  static const _kBaseUrl = 'llm_base_url';
  static const _kApiKey = 'llm_api_key';
  static const _kModel = 'llm_model';

  static Future<LlmSettings> load() async {
    final p = await SharedPreferences.getInstance();
    const def = LlmSettings();
    return LlmSettings(
      baseUrl: p.getString(_kBaseUrl) ?? def.baseUrl,
      apiKey: p.getString(_kApiKey) ?? def.apiKey,
      model: p.getString(_kModel) ?? def.model,
    );
  }

  static Future<void> save(LlmSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, s.baseUrl);
    await p.setString(_kApiKey, s.apiKey);
    await p.setString(_kModel, s.model);
  }
}
