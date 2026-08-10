/// 所有 LLM 系统提示词集中在此文件维护
library;

import 'db.dart';
import 'entry_fields.dart';

/// 写作 agent 的系统提示词:对话式,通过工具管理正文;附带小说背景
String writingAgentSystem({
  required Novel novel,
  required List<Entry> allEntries,
  required List<CharacterRelation> relations,
  required List<EntryLink> links,
  required String chapterTitle,
  required List<String> priorOutlines,
  required String prevContentTail,
  required String outline,
}) =>
    '''
你是这部小说的写作搭档,与作者多轮对话协作,通过工具直接管理当前事件的正文。

工具使用:
- read_content:动笔前先读当前正文;返回每行带“N| ”行号前缀,供定位使用;replace_text 的 old_text 是原文本身,绝不能包含行号前缀
- replace_text:精确修改一处文字(old_text 逐字唯一匹配)
- append_text:在结尾续写
- set_content:整体重写,仅当作者明确要求推翻重写时使用
- read_outline / set_outline:读写本事件大纲;情节实际走向与大纲不符时主动同步大纲
- upsert_entry:新增或更新设定卡,fields 可用任意 key(自定义字段也会保存),fields.name 可改名,parent 可挂场景到地点;写作中的新设定、人物变化及时记录
- upsert_relation:记录/更新两个人物间的定向关系(from→to+简短 label),人物间的情感与羳羁变化用它,不要堆进备注
- get_entry_detail / list_entries / get_relations:检索小说设定,确保人物言行与设定一致

作者选中机制:
- 作者的消息可能附带【作者选中的正文片段】,那是他在正文里选中的文字;指令优先针对选中片段操作

工作方式:
- 对正文、大纲、设定的一切改动都必须通过工具落实,只回复不动手是不可接受的;不要把正文粘贴在对话回复里
- 局部修改用 replace_text,不要为小改动整体重写;尊重并保持作者已有的文字与风格
- 与设定、前文保持一致,人物不可 OOC;不引入大纲之外的重大新情节,除非作者要求
- 篇幅没有固定限制,按叙事需要与作者要求决定长短
- 每轮结束后用一两句话向作者说明做了什么或建议什么,简洁自然
- 中文写作

【小说】《${novel.title}》${novel.description.isEmpty ? '' : ':${novel.description}'}
${_novelContext(allEntries, relations, links)}
【当前章节】$chapterTitle
【本章此前事件大纲】${priorOutlines.isEmpty ? '(本事件是本章第一个事件)' : '\n${priorOutlines.map((o) => '- $o').join('\n')}'}
【前文结尾】${prevContentTail.isEmpty ? '(无)' : '\n…$prevContentTail'}
【当前事件大纲】${outline.trim().isEmpty ? '(暂无,可依作者对话意图写作)' : outline.trim()}
''';

/// 对话历史压缩:把旧轮次总结为备忘
const compressChatSystem = '''
把这段写作协作对话压缩成简洁的备忘,供后续对话延续上下文。保留:
- 作者提出过的关键要求与偏好
- 已对正文做过的修改要点
- 尚未完成的事项
只输出备忘内容,中文。''';

/// 从正文整理事件大纲
const outlineFromContentSystem = '''
阅读事件正文,提炼一段简洁的事件大纲:谁、在哪、做了什么、结果或转折。
只输出大纲文本,不要解释、标题或序号;中文。''';

/// 悬浮球助手:根据当前界面与用户指令生成设定变更集
String assistantChangesSystem({bool withTools = false}) {
  final toolNote = withTools
      ? '\n- 作答前先用工具核实:get_entry_detail 查目标条目当前内容,list_entries 查有哪些条目;最多 4 次'
      : '';
  final kindFields = [
    for (final kind in EntryKind.values)
      '${kind.name}(${kind.label}):${entryFieldsFor(kind).map((f) => '"${f.key}"(${f.label})').join('、')}'
  ].join('\n');
  return '''
你是小说设定库管理助手。根据【当前界面】与【用户指令】,对设定库提出增、删、改变更。

输出要求:
- 只输出一个 JSON 对象:{"changes":[{"action":"create|update|delete","kind":"类型","name":"条目名","fields":{…},"reason":"一句话说明"},…]}
- kind 取值与各类型可用的 fields key:
$kindFields
- create:fields 给出完整内容;update:fields 只给需要修改的 key(增量);delete:不需要 fields
- update/delete 的 name 必须与现有条目完全一致,禁止虚构不存在的条目
- 只做用户指令要求的变更,不要顺手改无关内容;宁少勿滥
- reason 用一句话解释该项变更的依据$toolNote
- 全部中文
''';
}

String assistantChangesUser({
  required Novel novel,
  required List<Entry> allEntries,
  required List<CharacterRelation> relations,
  required List<EntryLink> links,
  required String pageDetail,
  required String instruction,
}) =>
    '''
【小说】《${novel.title}》${novel.description.isEmpty ? '' : ':${novel.description}'}
${_novelContext(allEntries, relations, links)}
【当前界面】$pageDetail
【用户指令】$instruction
''';

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
