import 'db.dart';
import 'entry_fields.dart';
import 'llm_client.dart';

/// AI 提议的一项设定变更
class EntryChange {
  EntryChange({
    required this.action,
    required this.kind,
    required this.name,
    this.fields = const {},
    this.reason = '',
  });

  final String action; // create / update / delete
  final EntryKind kind;
  final String name;
  final Map<String, String> fields;
  final String reason;

  String get actionLabel =>
      switch (action) { 'create' => '新增', 'update' => '修改', _ => '删除' };
}

/// 从模型回复解析变更集
List<EntryChange> parseChanges(String reply) {
  final data = LlmClient.parseJsonReply(reply);
  final raw = data['changes'];
  if (raw is! List) throw LlmException('模型未返回变更列表,请重试');
  final changes = <EntryChange>[];
  for (final c in raw) {
    if (c is! Map) continue;
    final action = c['action']?.toString() ?? '';
    if (!['create', 'update', 'delete'].contains(action)) continue;
    final kindName = c['kind']?.toString() ?? '';
    final kind = EntryKind.values.asNameMap()[kindName];
    final name = c['name']?.toString().trim() ?? '';
    if (kind == null || name.isEmpty) continue;
    final fields = <String, String>{};
    final f = c['fields'];
    if (f is Map) {
      final valid = {for (final ef in entryFieldsFor(kind)) ef.key};
      for (final e in f.entries) {
        if (valid.contains(e.key.toString()) && e.value != null) {
          fields[e.key.toString()] = e.value.toString();
        }
      }
    }
    changes.add(EntryChange(
      action: action,
      kind: kind,
      name: name,
      fields: fields,
      reason: c['reason']?.toString() ?? '',
    ));
  }
  if (changes.isEmpty) throw LlmException('模型未返回有效变更,请重试');
  return changes;
}

/// 应用选中的变更;返回 (成功数, 失败描述列表)
Future<(int, List<String>)> applyChanges(
    AppDatabase db, int novelId, List<EntryChange> changes) async {
  var ok = 0;
  final failed = <String>[];
  final all = await db.allEntriesOf(novelId);
  Entry? find(EntryChange c) {
    for (final e in all) {
      if (e.kind == c.kind.name && e.name == c.name) return e;
    }
    return null;
  }

  for (final c in changes) {
    try {
      switch (c.action) {
        case 'create':
          await db.createEntry(
              novelId, c.kind, c.name, encodeEntryContent(c.fields));
          ok++;
        case 'update':
          final target = find(c);
          if (target == null) {
            failed.add('未找到${c.kind.label}「${c.name}」');
            break;
          }
          final merged = parseEntryContent(target.content)..addAll(c.fields);
          await db.updateEntry(
              target.id, target.name, encodeEntryContent(merged));
          ok++;
        case 'delete':
          final target = find(c);
          if (target == null) {
            failed.add('未找到${c.kind.label}「${c.name}」');
            break;
          }
          await db.deleteEntry(target.id);
          ok++;
      }
    } catch (e) {
      failed.add('${c.actionLabel}${c.kind.label}「${c.name}」失败:$e');
    }
  }
  return (ok, failed);
}
