import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'settings.dart';

class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LlmClient {
  static const _timeout = Duration(seconds: 20);

  static String _base(LlmSettings s) {
    final url = s.baseUrl.trim();
    if (url.isEmpty) throw LlmException('请先填写 Base URL');
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Map<String, String> _headers(LlmSettings s) => {
        'Content-Type': 'application/json',
        if (s.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${s.apiKey.trim()}',
      };

  static Never _fail(Object e) {
    var msg = e is LlmException ? e.message : '请求失败:$e';
    if (kIsWeb && e is http.ClientException) {
      msg = '浏览器调试环境下请求被拦,可能是服务商未开放 CORS;'
          '此限制仅存在于 web 调试,桌面/手机端不受影响';
    }
    throw LlmException(msg);
  }

  /// 拉取可用模型列表(GET /models)
  static Future<List<String>> fetchModels(LlmSettings s) async {
    try {
      final resp = await http
          .get(Uri.parse('${_base(s)}/models'), headers: _headers(s))
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw LlmException('HTTP ${resp.statusCode}:${_errorText(resp)}');
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final models = (data['data'] as List?)
              ?.map((m) => m['id'] as String)
              .toList() ??
          [];
      if (models.isEmpty) throw LlmException('服务返回了空模型列表');
      models.sort();
      return models;
    } catch (e) {
      _fail(e);
    }
  }

  /// 发一条最小对话验证连通性,返回耗时(毫秒)
  static Future<int> testChat(LlmSettings s) async {
    if (s.model.trim().isEmpty) throw LlmException('请先填写模型名称');
    final watch = Stopwatch()..start();
    try {
      final resp = await http
          .post(Uri.parse('${_base(s)}/chat/completions'),
              headers: _headers(s),
              body: jsonEncode({
                'model': s.model.trim(),
                'messages': [
                  {'role': 'user', 'content': 'hi'}
                ],
                'max_tokens': 1,
              }))
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw LlmException('HTTP ${resp.statusCode}:${_errorText(resp)}');
      }
      return watch.elapsedMilliseconds;
    } catch (e) {
      _fail(e);
    }
  }

  /// 对话补全,返回模型回复文本
  static Future<String> chat(LlmSettings s,
      {required String system, required String user}) async {
    if (s.model.trim().isEmpty) {
      throw LlmException('请先在设置中配置 LLM API 与模型');
    }
    try {
      final resp = await http
          .post(Uri.parse('${_base(s)}/chat/completions'),
              headers: _headers(s),
              body: jsonEncode({
                'model': s.model.trim(),
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': user},
                ],
              }))
          .timeout(const Duration(seconds: 120));
      if (resp.statusCode != 200) {
        throw LlmException('HTTP ${resp.statusCode}:${_errorText(resp)}');
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw LlmException('模型返回了空内容');
      }
      return content;
    } catch (e) {
      _fail(e);
    }
  }

  /// 从模型回复中提取 JSON 对象(容忍代码围栏与前后缀文本)
  static Map<String, String> parseJsonReply(String text) {
    final t = text.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw LlmException('模型未返回 JSON,请重试或换个模型');
    }
    try {
      final d = jsonDecode(t.substring(start, end + 1)) as Map;
      return {
        for (final e in d.entries)
          if (e.value != null) e.key.toString(): e.value.toString()
      };
    } catch (_) {
      throw LlmException('模型返回的 JSON 无法解析,请重试');
    }
  }

  static String _errorText(http.Response resp) {
    try {
      final body = jsonDecode(utf8.decode(resp.bodyBytes));
      return body['error']?['message'] ?? resp.body;
    } catch (_) {
      final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
      return text.length > 200 ? text.substring(0, 200) : text;
    }
  }
}
