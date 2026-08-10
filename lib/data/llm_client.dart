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

/// 服务不支持 function calling 时抛出,调用方应回退普通对话
class ToolsUnsupportedException extends LlmException {
  ToolsUnsupportedException(super.message);
}

/// 用户主动停止生成
class LlmCancelledException extends LlmException {
  LlmCancelledException() : super('已停止');
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

  /// 带 function calling 的对话循环:模型可调用工具检索信息后再作答。
  /// 服务不支持 tools 时抛 [ToolsUnsupportedException],调用方可回退 [chat]。
  static Future<String> chatWithTools(
    LlmSettings s, {
    required String system,
    required String user,
    required List<Map<String, dynamic>> tools,
    required Future<String> Function(String name, Map<String, dynamic> args)
        onToolCall,
    int maxRounds = 6,
  }) async {
    if (s.model.trim().isEmpty) {
      throw LlmException('请先在设置中配置 LLM API 与模型');
    }
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ];
    try {
      for (var round = 0; round < maxRounds; round++) {
        final resp = await http
            .post(Uri.parse('${_base(s)}/chat/completions'),
                headers: _headers(s),
                body: jsonEncode({
                  'model': s.model.trim(),
                  'messages': messages,
                  'tools': tools,
                }))
            .timeout(const Duration(seconds: 120));
        if (resp.statusCode == 400 || resp.statusCode == 404) {
          throw ToolsUnsupportedException(_errorText(resp));
        }
        if (resp.statusCode != 200) {
          throw LlmException('HTTP ${resp.statusCode}：${_errorText(resp)}');
        }
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final msg = data['choices']?[0]?['message'] as Map<String, dynamic>?;
        if (msg == null) throw LlmException('模型返回格式异常');
        final toolCalls = msg['tool_calls'] as List?;
        if (toolCalls == null || toolCalls.isEmpty) {
          final content = msg['content'] as String?;
          if (content == null || content.trim().isEmpty) {
            throw LlmException('模型返回了空内容');
          }
          return content;
        }
        messages.add(msg);
        for (final tc in toolCalls) {
          final fn = tc['function'] as Map<String, dynamic>? ?? {};
          final name = fn['name'] as String? ?? '';
          Map<String, dynamic> args;
          try {
            final raw = fn['arguments'] as String? ?? '{}';
            args = raw.trim().isEmpty
                ? {}
                : (jsonDecode(raw) as Map).cast<String, dynamic>();
          } catch (_) {
            args = {};
          }
          String result;
          try {
            result = await onToolCall(name, args);
          } catch (e) {
            result = '工具执行失败：$e';
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'] ?? '',
            'content': result,
          });
        }
      }
      throw LlmException('工具调用轮次超限,请重试');
    } on ToolsUnsupportedException {
      rethrow;
    } catch (e) {
      _fail(e);
    }
  }
  /// 会话式工具循环:在调用方持有的 [messages] 上继续对话(user 消息已追加),
  /// 工具调用过程与最终回复都会留在 messages 中,构成对话记忆。
  static Future<String> chatTurn(
    LlmSettings s, {
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required Future<String> Function(String name, Map<String, dynamic> args)
        onToolCall,
    int maxRounds = 1000,
  }) async {
    if (s.model.trim().isEmpty) {
      throw LlmException('请先在设置中配置 LLM API 与模型');
    }
    try {
      for (var round = 0; round < maxRounds; round++) {
        final resp = await http
            .post(Uri.parse('${_base(s)}/chat/completions'),
                headers: _headers(s),
                body: jsonEncode({
                  'model': s.model.trim(),
                  'messages': messages,
                  'tools': tools,
                }))
            .timeout(const Duration(seconds: 180));
        if (resp.statusCode == 400 || resp.statusCode == 404) {
          throw ToolsUnsupportedException(_errorText(resp));
        }
        if (resp.statusCode != 200) {
          throw LlmException('HTTP ${resp.statusCode}:${_errorText(resp)}');
        }
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final msg = data['choices']?[0]?['message'] as Map<String, dynamic>?;
        if (msg == null) throw LlmException('模型返回格式异常');
        messages.add(msg);
        final toolCalls = msg['tool_calls'] as List?;
        if (toolCalls == null || toolCalls.isEmpty) {
          final content = msg['content'] as String?;
          if (content == null || content.trim().isEmpty) {
            throw LlmException('模型返回了空内容');
          }
          return content;
        }
        for (final tc in toolCalls) {
          final fn = tc['function'] as Map<String, dynamic>? ?? {};
          final name = fn['name'] as String? ?? '';
          Map<String, dynamic> args;
          try {
            final raw = fn['arguments'] as String? ?? '{}';
            args = raw.trim().isEmpty
                ? {}
                : (jsonDecode(raw) as Map).cast<String, dynamic>();
          } catch (_) {
            args = {};
          }
          String result;
          try {
            result = await onToolCall(name, args);
          } catch (e) {
            result = '工具执行失败：$e';
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'] ?? '',
            'content': result,
          });
        }
      }
      throw LlmException('工具调用轮次超限,请重试');
    } on ToolsUnsupportedException {
      rethrow;
    } catch (e) {
      _fail(e);
    }
  }

  /// 流式会话工具循环:文本增量经 [onDelta] 回调;工具调用照常执行。
  /// 注意 web 调试端 http 可能整体到达(降级为非流),原生端为真流式。
  static Future<String> chatTurnStream(
    LlmSettings s, {
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required Future<String> Function(String name, Map<String, dynamic> args)
        onToolCall,
    void Function(String delta)? onDelta,
    void Function(String name)? onToolStart,
    bool Function()? shouldStop,
    int maxRounds = 1000,
  }) async {
    if (s.model.trim().isEmpty) {
      throw LlmException('请先在设置中配置 LLM API 与模型');
    }
    bool stopped() => shouldStop?.call() ?? false;
    try {
      for (var round = 0; round < maxRounds; round++) {
        if (stopped()) throw LlmCancelledException();
        final client = http.Client();
        var contentBuf = '';
        final toolAcc = <int, Map<String, String>>{};
        try {
          final req = http.Request(
              'POST', Uri.parse('${_base(s)}/chat/completions'))
            ..headers.addAll(_headers(s))
            ..body = jsonEncode({
              'model': s.model.trim(),
              'messages': messages,
              'tools': tools,
              'stream': true,
            });
          final resp =
              await client.send(req).timeout(const Duration(seconds: 60));
          if (resp.statusCode == 400 || resp.statusCode == 404) {
            throw ToolsUnsupportedException(
                await resp.stream.bytesToString());
          }
          if (resp.statusCode != 200) {
            throw LlmException(
                'HTTP ${resp.statusCode}:${await resp.stream.bytesToString()}');
          }
          await for (final line in resp.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 120))) {
            if (stopped()) {
              // 保留已流出的文本到记忆,丢弃未完成的工具轮
              if (contentBuf.trim().isNotEmpty && toolAcc.isEmpty) {
                messages.add({'role': 'assistant', 'content': contentBuf});
              }
              throw LlmCancelledException();
            }
            if (!line.startsWith('data:')) continue;
            final payload = line.substring(5).trim();
            if (payload.isEmpty || payload == '[DONE]') continue;
            final Map<String, dynamic> j;
            try {
              j = jsonDecode(payload) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }
            final delta = j['choices']?[0]?['delta'];
            if (delta is! Map) continue;
            final c = delta['content'];
            if (c is String && c.isNotEmpty) {
              contentBuf += c;
              onDelta?.call(c);
            }
            final tcs = delta['tool_calls'];
            if (tcs is List) {
              for (final tc in tcs) {
                if (tc is! Map) continue;
                final idx = tc['index'] as int? ?? 0;
                final acc = toolAcc.putIfAbsent(
                    idx, () => {'id': '', 'name': '', 'args': ''});
                if (tc['id'] is String) acc['id'] = tc['id'] as String;
                final fn = tc['function'];
                if (fn is Map) {
                  if (fn['name'] is String) {
                    acc['name'] = acc['name']! + (fn['name'] as String);
                  }
                  if (fn['arguments'] is String) {
                    acc['args'] = acc['args']! + (fn['arguments'] as String);
                  }
                }
              }
            }
          }
        } finally {
          client.close();
        }
        if (toolAcc.isNotEmpty) {
          final calls = [
            for (final i in toolAcc.keys.toList()..sort())
              {
                'id': toolAcc[i]!['id'],
                'type': 'function',
                'function': {
                  'name': toolAcc[i]!['name'],
                  'arguments': toolAcc[i]!['args'],
                },
              }
          ];
          messages.add({
            'role': 'assistant',
            if (contentBuf.isNotEmpty) 'content': contentBuf,
            'tool_calls': calls,
          });
          for (final tc in calls) {
            final fn = tc['function'] as Map<String, dynamic>;
            final name = fn['name'] as String? ?? '';
            if (stopped()) {
              // 补齐剩余工具结果保持协议完整,再中止
              messages.add({
                'role': 'tool',
                'tool_call_id': tc['id'] ?? '',
                'content': '(用户中止)',
              });
              continue;
            }
            onToolStart?.call(name);
            Map<String, dynamic> args;
            try {
              final raw = fn['arguments'] as String? ?? '{}';
              args = raw.trim().isEmpty
                  ? {}
                  : (jsonDecode(raw) as Map).cast<String, dynamic>();
            } catch (_) {
              args = {};
            }
            String result;
            try {
              result = await onToolCall(name, args);
            } catch (e) {
              result = '工具执行失败：$e';
            }
            messages.add({
              'role': 'tool',
              'tool_call_id': tc['id'] ?? '',
              'content': result,
            });
          }
          if (stopped()) throw LlmCancelledException();
          continue;
        }
        if (contentBuf.trim().isEmpty) {
          throw LlmException('模型返回了空内容');
        }
        messages.add({'role': 'assistant', 'content': contentBuf});
        return contentBuf;
      }
      throw LlmException('工具调用轮次超限,请重试');
    } on ToolsUnsupportedException {
      rethrow;
    } catch (e) {
      _fail(e);
    }
  }

  /// 从模型回复中提取 JSON 对象(容忍围栏与前后缀);值保留原始类型
  static Map<String, dynamic> parseJsonReply(String text) {
    final t = text.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw LlmException('模型未返回 JSON,请重试或换个模型');
    }
    try {
      final d = jsonDecode(t.substring(start, end + 1)) as Map;
      return {for (final e in d.entries) e.key.toString(): e.value};
    } catch (_) {
      throw LlmException('模型返回的 JSON 无法解析,请重试');
    }
  }

  /// 从模型回复中提取 JSON 数组(容忍围栏/对象包裹)
  static List<Map<String, dynamic>> parseJsonArrayReply(String text) {
    final t = text.trim();
    final start = t.indexOf('[');
    final end = t.lastIndexOf(']');
    if (start >= 0 && end > start) {
      try {
        final d = jsonDecode(t.substring(start, end + 1));
        if (d is List) {
          return [
            for (final e in d)
              if (e is Map) e.cast<String, dynamic>()
          ];
        }
      } catch (_) {}
    }
    // 容忍 {"items":[…]} 式包裹
    final os = t.indexOf('{');
    final oe = t.lastIndexOf('}');
    if (os >= 0 && oe > os) {
      try {
        final obj = jsonDecode(t.substring(os, oe + 1));
        if (obj is Map) {
          for (final v in obj.values) {
            if (v is List) {
              return [
                for (final e in v)
                  if (e is Map) e.cast<String, dynamic>()
              ];
            }
          }
        }
      } catch (_) {}
    }
    throw LlmException('模型未返回条目数组,请重试');
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
