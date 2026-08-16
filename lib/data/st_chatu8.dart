import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StChatu8Settings {
  const StChatu8Settings({
    this.backend = 'novelai',
    this.novelai = const {},
    this.comfyui = const {},
  });
  final String backend;
  final Map<String, dynamic> novelai;
  final Map<String, dynamic> comfyui;
  Map<String, dynamic> toJson() => {
    'backend': backend,
    'novelai': novelai,
    'comfyui': comfyui,
  };
  factory StChatu8Settings.fromJson(Map<String, dynamic> json) =>
      StChatu8Settings(
        backend: _backend(json),
        novelai: _map(json['novelai'] ?? json['novelAi'] ?? json),
        comfyui: _map(json['comfyui'] ?? json['comfyUI'] ?? json),
      );
  static String _backend(Map<String, dynamic> json) {
    final explicit = json['backend'] ?? json['imageBackend'] ?? json['mode'];
    if (explicit != null && explicit.toString().trim().isNotEmpty) {
      return explicit.toString().toLowerCase();
    }
    // ComfyUI API exports are maps of node id -> {class_type, inputs}.
    final looksLikeWorkflow = json.values.any(
      (v) => v is Map && v['class_type'] != null && v['inputs'] is Map,
    );
    return looksLikeWorkflow ? 'comfyui' : 'novelai';
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

class StChatu8Store {
  static const _key = 'st_chatu8_settings';
  static Future<StChatu8Settings?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StChatu8Settings.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(StChatu8Settings value) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(value.toJson()),
      );
  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
  static StChatu8Settings parseImport(String text) {
    final root = jsonDecode(text);
    if (root is! Map) throw const FormatException('st-chat8 配置必须是 JSON 对象');
    final ext = root['extension_settings'];
    final scoped = ext is Map ? ext['st-chatu8'] : null;
    final value = scoped is Map ? scoped : root;
    return StChatu8Settings.fromJson(Map<String, dynamic>.from(value));
  }
}

class StChatu8ImageClient {
  static Future<Uint8List> generate(StChatu8Settings s, String prompt) async {
    if (s.backend.contains('comfy')) return _comfy(s.comfyui, prompt);
    return _novelAi(s.novelai, prompt);
  }

  static Future<Uint8List> _novelAi(
    Map<String, dynamic> c,
    String prompt,
  ) async {
    final key = _str(c, ['novelaiApi', 'apiKey', 'key']);
    final base = _str(c, ['novelaiOtherSite', 'baseUrl']).trim();
    final url = base.isEmpty
        ? 'https://image.novelai.net/ai/generate-image'
        : (base.contains('generate-image')
              ? base
              : '${base.replaceAll(RegExp(r'/+$'), '')}/ai/generate-image');
    final model = _str(c, [
      'novelaimode',
      'model',
    ], fallback: 'nai-diffusion-3');
    final width = _num(c, ['novelai_width', 'width'], 832).toInt();
    final height = _num(c, ['novelai_height', 'height'], 1216).toInt();
    final payload = {
      'input': prompt,
      'model': model,
      'action': 'generate',
      'parameters': {
        'width': width,
        'height': height,
        'n_samples': 1,
        'steps': _num(c, ['novelai_steps', 'steps'], 23).toInt(),
        'scale': _num(c, ['nai3Scale', 'scale'], 5),
        'sampler': _str(c, [
          'novelai_sampler',
          'sampler',
        ], fallback: 'k_euler_ancestral'),
        'qualityToggle': true,
        'ucPreset': 0,
        'negative_prompt': _str(c, [
          'negativePrompt_novelai',
          'negative_prompt',
        ]),
        'seed': _num(c, ['novelai_seed', 'seed'], -1).toInt(),
      },
    };
    final resp = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode < 200 || resp.statusCode >= 300)
      throw Exception('NovelAI HTTP ${resp.statusCode}: ${resp.body}');
    final ct = resp.headers['content-type'] ?? '';
    if (ct.contains('json')) {
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final b64 = (data['images'] as List?)?.firstOrNull?['image'] as String?;
      if (b64 != null) return base64Decode(b64);
    } else {
      for (final f in ZipDecoder().decodeBytes(resp.bodyBytes).files) {
        if (f.isFile) return Uint8List.fromList(f.content as List<int>);
      }
    }
    throw Exception('NovelAI 未返回图片数据');
  }

  static Future<Uint8List> _comfy(Map<String, dynamic> c, String prompt) async {
    final base = _str(c, [
      'comfyuiUrl',
      'url',
    ], fallback: 'http://127.0.0.1:8188').replaceAll(RegExp(r'/+$'), '');
    var workflow = c['workflow'] is Map
        ? Map<String, dynamic>.from(c['workflow'])
        : <String, dynamic>{};
    if (workflow.isEmpty && c['worker'] is String) {
      try {
        workflow = Map<String, dynamic>.from(jsonDecode(c['worker'] as String));
      } catch (_) {}
    }
    if (workflow.isEmpty) throw Exception('未导入 ComfyUI API 工作流');
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    _injectPrompt(workflow, prompt);
    final queued = await http
        .post(
          Uri.parse('$base/prompt'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': workflow, 'client_id': clientId}),
        )
        .timeout(const Duration(seconds: 30));
    if (queued.statusCode < 200 || queued.statusCode >= 300)
      throw Exception('ComfyUI HTTP ${queued.statusCode}: ${queued.body}');
    final queuedData = jsonDecode(queued.body);
    if (queuedData is! Map || queuedData['prompt_id'] == null) {
      final errors = queuedData is Map
          ? (queuedData['node_errors'] ?? queuedData['error'] ?? queued.body)
          : queued.body;
      throw Exception('ComfyUI 工作流校验失败：$errors');
    }
    final id = queuedData['prompt_id'].toString();
    for (var i = 0; i < 120; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final h = await http.get(Uri.parse('$base/history/$id'));
      if (h.statusCode != 200) continue;
      final item = jsonDecode(h.body)[id];
      final outputs = item?['outputs'] as Map?;
      for (final out in outputs?.values ?? const []) {
        for (final img
            in (out is Map ? (out['images'] as List? ?? const []) : const [])) {
          final u =
              '$base/view?filename=${Uri.encodeComponent(img['filename'])}&subfolder=${Uri.encodeComponent(img['subfolder'] ?? '')}&type=${img['type'] ?? 'output'}';
          final r = await http.get(Uri.parse(u));
          if (r.statusCode == 200) return r.bodyBytes;
        }
      }
    }
    throw Exception('ComfyUI 生成超时');
  }

  static void _injectPrompt(Map<String, dynamic> workflow, String prompt) {
    Map<String, dynamic>? positive;
    final scalarCandidates = <Map<String, dynamic>>[];
    for (final node in workflow.values) {
      if (node is! Map || node['inputs'] is! Map) continue;
      final inputs = Map<String, dynamic>.from(node['inputs'] as Map);
      final type = node['class_type']?.toString() ?? '';
      final title =
          (node['_meta'] is Map ? (node['_meta'] as Map)['title'] : null)
              ?.toString()
              .toLowerCase();
      if (inputs['value'] is String &&
          (type.contains('String') || type.contains('Prompt'))) {
        final candidate = <String, dynamic>{'inputs': inputs, 'node': node};
        if (title?.contains('正面') == true ||
            title?.contains('positive') == true) {
          positive = candidate;
        } else {
          scalarCandidates.add(candidate);
        }
      }
      // Some minimal workflows use a direct scalar CLIPTextEncode field.
      if (inputs['text'] is String) {
        final candidate = <String, dynamic>{'inputs': inputs, 'node': node};
        if (title?.contains('正面') == true ||
            title?.contains('positive') == true)
          positive = candidate;
        scalarCandidates.add(candidate);
      }
      for (final key in ['prompt', 'positive']) {
        if (inputs[key] is String) {
          scalarCandidates.add(<String, dynamic>{
            'inputs': inputs,
            'node': node,
            'key': key,
          });
        }
      }
    }
    final chosen =
        positive ??
        (scalarCandidates.isNotEmpty ? scalarCandidates.first : null);
    if (chosen == null) throw Exception('ComfyUI 工作流中找不到可注入的正向提示词字段');
    final inputs = chosen['inputs'] as Map<String, dynamic>;
    final key =
        chosen['key']?.toString() ??
        (inputs.containsKey('value') ? 'value' : 'text');
    inputs[key] = prompt;
    (chosen['node'] as Map)['inputs'] = inputs;
    _applyGenerationDefaults(workflow);
  }

  static void _applyGenerationDefaults(Map<String, dynamic> workflow) {
    for (final node in workflow.values) {
      if (node is! Map || node['inputs'] is! Map) continue;
      final inputs = node['inputs'] as Map;
      final type = node['class_type']?.toString().toLowerCase() ?? '';
      final title =
          (node['_meta'] is Map ? (node['_meta'] as Map)['title'] : null)
              ?.toString()
              .toLowerCase() ??
          '';
      if ((type.contains('conditionalsaveimage') ||
              type.contains('saveimage')) &&
          (title.contains('底图') ||
              inputs['filename_prefix']?.toString().contains('底图') == true)) {
        if (inputs['enabled'] is bool) inputs['enabled'] = false;
      }
      if (type.contains('primitiveint') &&
          title.contains('批量') &&
          inputs['value'] is num) {
        inputs['value'] = 2;
      } else if (type == 'emptylatentimage' && inputs['batch_size'] is num) {
        inputs['batch_size'] = 2;
      }
      for (final key in ['upscale_model', 'upscaleModel', 'model_name']) {
        if (inputs[key] is String &&
            inputs[key].toString().toLowerCase().contains('svr')) {
          inputs[key] = 'SVR2';
        }
      }
    }
  }

  static String _str(
    Map<String, dynamic> m,
    List<String> keys, {
    String fallback = '',
  }) => keys
      .map((k) => m[k])
      .firstWhere(
        (v) => v != null && v.toString().isNotEmpty,
        orElse: () => fallback,
      )
      .toString();
  static num _num(Map<String, dynamic> m, List<String> keys, num fallback) =>
      num.tryParse(_str(m, keys)) ?? fallback;
}
