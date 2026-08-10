import 'novel_tools.dart';

/// 写作 agent 的正文编辑工具(类编程 agent 的 read/write 范式)
const writingToolSchemas = [
  {
    'type': 'function',
    'function': {
      'name': 'read_content',
      'description': '读取当前事件正文全文;修改前必须先读,确保 replace_text 的原文逐字一致',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'replace_text',
      'description': '精确替换正文中的一段文字;old_text 必须与正文某处逐字一致且全文唯一',
      'parameters': {
        'type': 'object',
        'properties': {
          'old_text': {'type': 'string', 'description': '要被替换的原文片段(逐字)'},
          'new_text': {'type': 'string', 'description': '替换后的新文字'},
        },
        'required': ['old_text', 'new_text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'append_text',
      'description': '在正文结尾追加内容(续写)',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '要追加的内容'}
        },
        'required': ['text'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_content',
      'description': '整体重写正文;仅当作者明确要求推翻重写时使用',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': '新的正文全文'}
        },
        'required': ['text'],
      },
    },
  },
];

/// 执行正文编辑工具;设定检索类工具转发给 [NovelToolExecutor]
class WritingToolExecutor {
  WritingToolExecutor({
    required this.readContent,
    required this.writeContent,
    required this.lookup,
  });

  /// 实时读取正文(编辑框内容)
  final String Function() readContent;

  /// 写回正文(编辑框内容)
  final void Function(String) writeContent;

  final NovelToolExecutor lookup;

  Future<String> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'read_content':
        final c = readContent();
        return c.trim().isEmpty ? '(正文目前为空)' : c;
      case 'replace_text':
        final oldText = args['old_text'] as String? ?? '';
        final newText = args['new_text'] as String? ?? '';
        if (oldText.isEmpty) return '失败:old_text 为空';
        final content = readContent();
        final count = oldText.allMatches(content).length;
        if (count == 0) {
          return '失败:正文中未找到该片段,请先 read_content 核对原文';
        }
        if (count > 1) {
          return '失败:该片段在正文中出现 $count 处,请提供更长的唯一片段';
        }
        writeContent(content.replaceFirst(oldText, newText));
        return '已替换';
      case 'append_text':
        final text = args['text'] as String? ?? '';
        if (text.isEmpty) return '失败:text 为空';
        final content = readContent();
        writeContent(
            content.trim().isEmpty ? text : '${content.trimRight()}\n\n$text');
        return '已追加';
      case 'set_content':
        writeContent(args['text'] as String? ?? '');
        return '已重写全文';
      default:
        return lookup.call(name, args);
    }
  }
}
