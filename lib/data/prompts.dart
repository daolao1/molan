/// 所有 LLM 系统提示词集中在此文件维护
library;

import 'db.dart';
import 'entry_fields.dart';

/// AI 生成模式
enum GenerationMode {
  /// 自由发挥,填满整张卡片
  generate('生成'),

  /// 只写用户明确提到的内容
  supplement('补充');

  const GenerationMode(this.label);
  final String label;
}

/// 生成设定卡的系统提示词;withTools 为真时告知模型可用检索工具
String entryGenerationSystem(EntryKind kind,
    {required GenerationMode mode, bool withTools = false}) {
  final fields = entryFieldsFor(kind);
  final keys =
      fields.map((f) => '"${f.key}"(${f.label}:${f.hint})').join('、');
  final toolNote = withTools
      ? '''
- 作答前先用工具检索:用 get_entry_detail 查看与【生成要求】相关条目的完整设定,用 get_relations 查人物关系;最多检索 4 次,查完再输出最终 JSON'''
      : '';
  final relNote = kind == EntryKind.character
      ? '''
- 可额外返回 "relations":[{"target":"人物名","label":"关系"}] 描述本人物与其他人物的关系;target 必须是【现有设定】中已存在的人物名,禁止虚构;label 用 2~6 字(如:师徒、血仇、青梅竹马);没有合适对象就不返回该 key'''
      : kind == EntryKind.lore
          ? '''
- 可额外返回 "related":["卡片名"] 列出与本设定相关的已有卡片(人物/地点/物品/场景/设定);名字必须取自【现有设定】,禁止虚构;没有就不返回该 key'''
          : '';
  final common = '''
- 只输出一个 JSON 对象,禁止输出任何解释、前后缀或代码围栏
- 可用的 key:"name"(名称)、$keys
- 全部用中文撰写;内容具体、有画面感、可直接用于写作,避免空泛套话
- 充分利用【现有设定】:与已有人物、地点、物品、场景建立合理的关联与呼应,严禁与现有设定矛盾$toolNote$relNote
- 单行字段控制在 30 字内,多行字段 50~150 字''';
  if (mode == GenerationMode.generate) {
    return '''
你是资深小说设定师,负责为作者生成高质量的${kind.label}设定卡。

输出要求:
- 返回完整设定卡:包含 "name" 与全部字段,可在【生成要求】基础上自由发挥补足细节
- 若用户已填部分字段,尊重其设定并在此基础上完善
- 不得与已有条目重名
$common
''';
  }
  return '''
你是资深小说设定师,本次任务是按作者指令对${kind.label}设定卡做定点补充。

输出要求:
- 只输出与【生成要求】直接相关的字段;用户未提及的方面一律不要返回,即使那些字段目前为空也不要主动填写
- 不要自由发挥新设定;忠实于用户的描述,仅做必要的文字打磨
- 相关字段已有内容时,保留原有要点,把新设定自然融入而不是推翻重写
- 除非【生成要求】明确要求,否则不要修改 "name"
$common
''';
}

/// 每类条目注入上下文的数量上限(防止提示词过长)
const _maxEntriesPerKind = 15;

/// 现有设定摘要:五类条目 + 人物关系网 + 设定关联
String _novelContext(List<Entry> allEntries,
    List<CharacterRelation> relations, List<EntryLink> links) {
  final buf = StringBuffer();
  final nameOf = {for (final e in allEntries) e.id: e.name};
  final linksOf = <int, List<String>>{};
  for (final l in links) {
    final to = nameOf[l.toEntryId];
    if (to != null) (linksOf[l.fromEntryId] ??= []).add(to);
  }
  for (final kind in EntryKind.values) {
    final list = [
      for (final e in allEntries)
        if (e.kind == kind.name) e
    ];
    if (list.isEmpty) continue;
    buf.writeln('【已有${kind.label}】(${list.length}个)');
    for (final e in list.take(_maxEntriesPerKind)) {
      final brief = entryBrief(e);
      final parent = e.parentId == null ? '' : '(属于:${nameOf[e.parentId]})';
      final linked = linksOf[e.id] == null
          ? ''
          : '(关联:${linksOf[e.id]!.join('、')})';
      buf.writeln(
          '- ${e.name}$parent$linked${brief.isEmpty ? '' : ':$brief'}');
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

/// 批量生成世界观设定条目的系统提示词
String loreGenerationSystem({bool withTools = false}) {
  final toolNote = withTools
      ? '\n- 作答前可用工具检索现有设定细节(get_entry_detail / list_entries / get_relations),最多 4 次'
      : '';
  return '''
你是资深小说设定师,负责为小说批量生成世界观设定条目。

输出要求:
- 只输出一个 JSON 数组,形如 [{"name":"条目名","detail":"条目内容","related":["卡片名"]},…],禁止任何其他文字或代码围栏
- 条目数量严格跟随【生成要求】的语义:只提了一个主题就返回 1 条;明确列出多个主题(如用顿号、分号分隔)或指定了数量时,才按对应数量返回
- 不要自行把一个主题拆成多条,也不要主动补充未要求的设定
- 每条内容聚焦自身主题、独立自洽:不要在 detail 中复述或混入其他设定的内容,与其他卡片的联系仅通过 related 字段表达
- name 简短(2~10 字),detail 100~300 字,具体可直接用于写作
- related 可选:列出与该条相关的已有卡片名(必须取自【现有设定】,禁止虚构)
- 不与已有设定重名,严禁与现有设定矛盾$toolNote
- 全部用中文撰写
''';
}

/// 批量生成设定的用户消息
String loreGenerationUser({
  required Novel novel,
  required List<Entry> allEntries,
  required List<CharacterRelation> relations,
  required List<EntryLink> links,
  required String request,
}) =>
    '''
【小说】《${novel.title}》${novel.description.isEmpty ? '' : ':${novel.description}'}
${_novelContext(allEntries, relations, links)}
【生成要求】$request
''';

/// 生成设定卡的用户消息(动态携带全书现有设定)
String entryGenerationUser({
  required Novel novel,
  required EntryKind kind,
  required List<Entry> allEntries,
  required List<CharacterRelation> relations,
  required List<EntryLink> links,
  required String currentName,
  required Map<String, String> currentData,
  required String request,
  String? parentLocation,
}) {
  final fields = entryFieldsFor(kind);
  final filled = [
    if (currentName.trim().isNotEmpty) '名称:${currentName.trim()}',
    for (final f in fields)
      if ((currentData[f.key] ?? '').trim().isNotEmpty)
        '${f.label}:${currentData[f.key]!.trim()}',
  ];
  final creating = parentLocation == null
      ? kind.label
      : '${kind.label}(属于地点:$parentLocation)';
  return '''
【小说】《${novel.title}》${novel.description.isEmpty ? '' : ':${novel.description}'}
${_novelContext(allEntries, relations, links)}
【正在创建】$creating
【已填写的字段】${filled.isEmpty ? '(无)' : '\n${filled.join('\n')}'}
【生成要求】$request
''';
}
