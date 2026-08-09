import 'dart:convert';

import 'db.dart';

/// 设定卡的一个字段;lines > 1 表示多行文本
class EntryField {
  const EntryField(this.key, this.label, this.hint, [this.lines = 1]);

  final String key;
  final String label;
  final String hint;
  final int lines;
}

const _characterFields = [
  EntryField('alias', '别名/称号', '道号、绰号、封号等'),
  EntryField('basic', '基本信息', '性别、年龄、种族、身份、所属势力', 2),
  EntryField('appearance', '外貌', '容貌、身形、衣着、标志性特征', 3),
  EntryField('personality', '性格', '性格特点、说话方式、习惯、软肋', 3),
  EntryField('background', '背景经历', '出身与重要过往', 4),
  EntryField('abilities', '能力/特长', '功法、技能、天赋、装备', 3),
  EntryField('notes', '备注', '其他补充', 3),
];

const _locationFields = [
  EntryField('region', '位置/区域', '所属地域、如何到达'),
  EntryField('description', '环境描写', '外观、气候、声音气味、氛围', 4),
  EntryField('faction', '势力/居民', '统治者、主要人群、立场', 3),
  EntryField('history', '历史渊源', '来历与传说', 3),
  EntryField('events', '相关剧情', '在此发生过/将发生的事件', 3),
  EntryField('notes', '备注', '其他补充', 3),
];

const _itemFields = [
  EntryField('type', '类型', '武器 / 法宝 / 信物 / 丹药…'),
  EntryField('appearance', '外观', '形制、材质、特征', 3),
  EntryField('origin', '来历', '出处、铸造者、流转经过', 3),
  EntryField('power', '能力/作用', '功效、限制、代价', 3),
  EntryField('owner', '持有者/下落', '现在在谁手里'),
  EntryField('notes', '备注', '其他补充', 3),
];

const _sceneFields = [
  EntryField('position', '相对位置', '在所属地点中的方位,如:主殿西侧、地下三层、后山小径尽头'),
  EntryField('description', '环境描写', '外观、陈设、光线、声音气味、氛围', 4),
  EntryField('function', '用途/功能', '这里通常发生什么、谁会来', 2),
  EntryField('details', '细节与机关', '值得注意的物件、暗门、禁制等', 3),
  EntryField('notes', '备注', '其他补充', 3),
];

const _loreFields = [
  EntryField('detail', '内容', '这条设定的具体描述', 6),
];

List<EntryField> entryFieldsFor(EntryKind kind) => switch (kind) {
      EntryKind.character => _characterFields,
      EntryKind.location => _locationFields,
      EntryKind.item => _itemFields,
      EntryKind.scene => _sceneFields,
      EntryKind.lore => _loreFields,
    };

/// content 为 JSON map;旧版纯文本数据归入备注
Map<String, String> parseEntryContent(String content) {
  if (content.trim().isEmpty) return {};
  try {
    final d = jsonDecode(content);
    if (d is Map) {
      return d.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
  } catch (_) {}
  return {'notes': content};
}

String encodeEntryContent(Map<String, String> data) {
  final cleaned = {
    for (final e in data.entries)
      if (e.value.trim().isNotEmpty) e.key: e.value.trim()
  };
  return cleaned.isEmpty ? '' : jsonEncode(cleaned);
}

/// 列表副标题:按模板顺序取第一个非空字段
String entrySubtitle(Entry e) {
  final data = parseEntryContent(e.content);
  for (final f in entryFieldsFor(EntryKind.values.byName(e.kind))) {
    final v = data[f.key]?.trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// 拼接多字段的短摘要,供 LLM 上下文使用
String entryBrief(Entry e, {int maxLen = 80}) {
  final data = parseEntryContent(e.content);
  final buf = StringBuffer();
  for (final f in entryFieldsFor(EntryKind.values.byName(e.kind))) {
    final v = data[f.key]?.replaceAll('\n', ' ').trim() ?? '';
    if (v.isEmpty) continue;
    if (buf.isNotEmpty) buf.write(';');
    buf.write(v);
    if (buf.length >= maxLen) break;
  }
  final s = buf.toString();
  return s.length <= maxLen ? s : '${s.substring(0, maxLen)}…';
}
