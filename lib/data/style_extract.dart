/// 文风萃取:从 txt/epub 材料中全方位分析写作风格,产出设定卡组成设定集。
///
/// 设计参考:
/// - arXiv 2410.03848(提示工程引导 LLM 学习个人语言风格:分析→归纳→例句证据)
/// - The Definitive Guide to LLM Writing Styles 的特征框架(词汇/句法/节奏/修辞/视角)
/// - 本应用文笔准则的维度(情感外化、感知边界、段落呼吸)
library;

import 'dart:convert';

import 'package:archive/archive.dart';

/// 萃取维度:每项生成一张设定卡
const styleDimensions = [
  ('叙事视角与距离', '人称、视角类型(全知/限知/贴身)、叙述者与人物的距离、视角切换习惯'),
  ('句式与节奏', '平均句长与分布、长短句交替规律、标点习惯(逗号密度/破折号/省略号)、段落长度与切分逻辑'),
  ('词汇与质感', '用词偏好(文言/口语/书面)、高频特征词与口头禅、动词名词形容词的倾向、避用的词类'),
  ('对白风格', '对白与叙述的比例、对白标签习惯、人物语言的区分度、对白与动作的交织方式'),
  ('描写手法', '感官侧重(视/听/触/嗅)、景物与人物描写的详略、比喻意象的类型与频率、留白习惯'),
  ('情感表达', '情感直陈还是外化、内心活动的呈现方式、情绪高潮的处理手法、克制或浓烈的倾向'),
  ('叙事技法', '时间处理(线性/闪回)、场景转换方式、悬念与伏笔的埋设习惯、开头与结尾的模式'),
];

/// 萃取 agent 的系统提示词:一次分析一个维度,输出规范可直接用于写作指导
String styleExtractSystem(String dimension, String hint) => '''
你是文体学专家,负责从给定的文学材料中萃取「$dimension」维度的写作风格,写成可直接指导仿写的风格规范。

分析要点:$hint

输出要求:
- 只输出一个 JSON 对象:{"detail":"规范正文"}
- 规范正文 200~400 字:先用两三句概括该维度的核心特征,再列 3~5 条具体可执行的仿写规则
- 每条规则必须附一个从材料中摘出的原文短例(15 字内,用「」包裹)作为证据,禁止编造
- 写给仿写者看:用祈使句("多用…""避免…""在…时…"),不写文学评论套话
- 只描述材料中真实存在的特征;拿不准的宁可不写
- 全部中文
''';

/// epub 解包:解压 zip,按 spine 顺序近似(文件名排序)拼接正文,剥除 HTML 标签
String extractEpubText(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final parts = <MapEntry<String, String>>[];
  for (final f in archive.files) {
    final name = f.name.toLowerCase();
    if (!f.isFile) continue;
    if (name.endsWith('.xhtml') || name.endsWith('.html') || name.endsWith('.htm')) {
      try {
        parts.add(MapEntry(f.name, utf8.decode(f.content as List<int>, allowMalformed: true)));
      } catch (_) {}
    }
  }
  parts.sort((a, b) => a.key.compareTo(b.key));
  final buf = StringBuffer();
  for (final p in parts) {
    buf.writeln(_stripHtml(p.value));
  }
  return buf.toString();
}

String _stripHtml(String html) {
  var t = html
      .replaceAll(RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h[1-6]|li)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return t.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// 长材料采样:开头/中段/结尾各取一段,总量控制在 [cap] 字以内
String sampleMaterial(String text, {int cap = 24000}) {
  final t = text.trim();
  if (t.length <= cap) return t;
  final part = cap ~/ 3;
  final mid = t.length ~/ 2;
  return '${t.substring(0, part)}\n\n…(中段)…\n\n'
      '${t.substring(mid - part ~/ 2, mid + part ~/ 2)}\n\n…(结尾)…\n\n'
      '${t.substring(t.length - part)}';
}
