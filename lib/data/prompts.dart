/// 所有 LLM 系统提示词集中在此文件维护
library;

import 'db.dart';
import 'entry_fields.dart';

/// 生成设定卡的系统提示词;incremental 为真时只增量完善已有卡片;
/// withTools 为真时告知模型可用检索工具
String entryGenerationSystem(EntryKind kind,
    {required bool incremental, bool withTools = false}) {
  final fields = entryFieldsFor(kind);
  final keys =
      fields.map((f) => '"${f.key}"(${f.label}:${f.hint})').join('、');
  final toolNote = withTools
      ? '''
- 作答前先用工具检索:用 get_entry_detail 查看与【生成要求】相关条目的完整设定,用 get_relations 查人物关系;最多检索 4 次,查完再输出最终 JSON'''
      : '';
  final common = '''
- 只输出一个 JSON 对象,禁止输出任何解释、前后缀或代码围栏
- 可用的 key:"name"(名称)、$keys
- 全部用中文撰写;内容具体、有画面感、可直接用于写作,避免空泛套话
- 充分利用【现有设定】:与已有人物、地点、物品、场景建立合理的关联与呼应,严禁与现有设定矛盾$toolNote
- 单行字段控制在 30 字内,多行字段 50~150 字''';
  if (!incremental) {
    return '''
你是资深小说设定师,负责为作者生成高质量的${kind.label}设定卡。

输出要求:
- 返回完整设定卡:包含 "name" 与全部字段
- 不得与已有条目重名
$common
''';
  }
  return '''
你是资深小说设定师。用户已有一张填写过的${kind.label}设定卡,本次任务是根据【生成要求】做增量完善。

输出要求:
- 只返回需要新增或修改的字段;内容不变的字段一律不要出现在 JSON 中
- 已填内容默认保留:修改某字段时保留其原有要点,把新设定自然融入,而不是推翻重写
- 除非【生成要求】明确要求,否则不要修改 "name"
$common
''';
}

/// 每类条目注入上下文的数量上限(防止提示词过长)
const _maxEntriesPerKind = 15;

/// 现有设定摘要:四类条目 + 人物关系网
String _novelContext(
    List<Entry> allEntries, List<CharacterRelation> relations) {
  final buf = StringBuffer();
  final nameOf = {for (final e in allEntries) e.id: e.name};
  for (final kind in EntryKind.values) {
    final list = [
      for (final e in allEntries)
        if (e.kind == kind.name) e
    ];
    if (list.isEmpty) continue;
    buf.writeln('【已有${kind.label}】(${list.length}个)');
    for (final e in list.take(_maxEntriesPerKind)) {
      final brief = entryBrief(e);
      buf.writeln('- ${e.name}${brief.isEmpty ? '' : ':$brief'}');
    }
    if (list.length > _maxEntriesPerKind) {
      buf.writeln(
          '- (另有 ${list.length - _maxEntriesPerKind} 个:${list.skip(_maxEntriesPerKind).map((e) => e.name).join('、')})');
    }
  }
  if (relations.isNotEmpty) {
    buf.writeln('【人物关系】');
    for (final r in relations) {
      final from = nameOf[r.fromEntryId];
      final to = nameOf[r.toEntryId];
      if (from != null && to != null) {
        buf.writeln('- $from →${r.label}→ $to');
      }
    }
  }
  return buf.isEmpty ? '(暂无任何设定)' : buf.toString().trimRight();
}

/// 生成设定卡的用户消息(动态携带全书现有设定)
String entryGenerationUser({
  required Novel novel,
  required EntryKind kind,
  required List<Entry> allEntries,
  required List<CharacterRelation> relations,
  required String currentName,
  required Map<String, String> currentData,
  required String request,
}) {
  final fields = entryFieldsFor(kind);
  final filled = [
    if (currentName.trim().isNotEmpty) '名称:${currentName.trim()}',
    for (final f in fields)
      if ((currentData[f.key] ?? '').trim().isNotEmpty)
        '${f.label}:${currentData[f.key]!.trim()}',
  ];
  return '''
【小说】《${novel.title}》${novel.description.isEmpty ? '' : ':${novel.description}'}
${_novelContext(allEntries, relations)}
【正在创建】${kind.label}
【已填写的字段】${filled.isEmpty ? '(无)' : '\n${filled.join('\n')}'}
【生成要求】$request
''';
}
