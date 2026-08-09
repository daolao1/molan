/// 所有 LLM 系统提示词集中在此文件维护
library;

import 'db.dart';
import 'entry_fields.dart';

/// 生成设定卡的系统提示词
String entryGenerationSystem(EntryKind kind) {
  final fields = entryFieldsFor(kind);
  final keys =
      fields.map((f) => '"${f.key}"(${f.label}:${f.hint})').join('、');
  return '''
你是资深小说设定师,负责为作者生成高质量的${kind.label}设定卡。

输出要求:
- 只输出一个 JSON 对象,禁止输出任何解释、前后缀或代码围栏
- JSON 的 key 固定为:"name"(名称)、$keys
- 全部用中文撰写;内容具体、有画面感、可直接用于写作,避免空泛套话
- 严格贴合用户给出的小说背景与生成要求,风格统一
- 不得与已有条目重名;若用户已填部分字段,尊重其设定并在此基础上补全融合
- 单行字段控制在 30 字内,多行字段 50~150 字
''';
}

/// 生成设定卡的用户消息
String entryGenerationUser({
  required Novel novel,
  required EntryKind kind,
  required List<String> existingNames,
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
【已有${kind.label}】${existingNames.isEmpty ? '(无)' : existingNames.join('、')}
【已填写的字段】${filled.isEmpty ? '(无)' : '\n${filled.join('\n')}'}
【生成要求】$request
''';
}
