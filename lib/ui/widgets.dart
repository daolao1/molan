import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';

/// 新建/编辑设定集对话框(设定页与写作页共用);返回是否有变更
Future<bool> showEditSetDialog(BuildContext context, AppDatabase db,
    int novelId, List<Entry> all, EntrySet? editing) async {
  final nameCtrl = TextEditingController(text: editing?.name ?? '');
  final picked = <int>{
    if (editing != null)
      for (final s in editing.entryIds.split(','))
        ?int.tryParse(s.trim())
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text(editing == null ? '新建设定集' : '编辑设定集'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: editing == null,
                decoration: const InputDecoration(
                    labelText: '集名',
                    hintText: '如:核心风格 / 主线包',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in all)
                        if (e.kind == EntryKind.lore.name)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.name),
                            value: picked.contains(e.id),
                            onChanged: (v) => setDialog(() => v == true
                                ? picked.add(e.id)
                                : picked.remove(e.id)),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(editing == null ? '创建' : '保存')),
        ],
      ),
    ),
  );
  final name = nameCtrl.text.trim();
  if (ok != true || name.isEmpty) return false;
  if (editing == null) {
    await db.createSet(novelId, name, picked.join(','));
  } else {
    await db.updateSet(editing.id, name, picked.join(','));
  }
  return true;
}

/// 物理键盘 Enter 触发提交,Shift+Enter 正常换行;移动端软键盘不受影响
class SubmitOnEnter extends StatelessWidget {
  const SubmitOnEnter(
      {super.key, required this.onSubmit, required this.child});

  final VoidCallback onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            !HardwareKeyboard.instance.isShiftPressed) {
          onSubmit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// 带持久高亮的正文控制器:高亮区间独立于选区,失焦仍然渲染;
/// 文本变化时自动迁移高亮,片段被改动则自然消失
class HighlightController extends TextEditingController {
  HighlightController({super.text});

  /// 当前钉住的高亮(字符区间);null 表示无
  TextRange? highlight;

  Color highlightColor = const Color(0x33FFC107);

  @override
  set value(TextEditingValue newValue) {
    final h = highlight;
    if (h != null && newValue.text != text) {
      final frag = h.end <= text.length && h.start < h.end
          ? text.substring(h.start, h.end)
          : '';
      highlight = frag.isEmpty ? null : _nearestRange(newValue.text, frag, h.start);
    }
    super.value = newValue;
  }

  /// 距原位置最近的匹配;找不到返回 null(高亮自然消失)
  static TextRange? _nearestRange(String text, String frag, int oldStart) {
    TextRange? best;
    var idx = text.indexOf(frag);
    while (idx >= 0) {
      if (best == null || (idx - oldStart).abs() < (best.start - oldStart).abs()) {
        best = TextRange(start: idx, end: idx + frag.length);
      }
      idx = text.indexOf(frag, idx + 1);
    }
    return best;
  }

  /// 钉住区间;越界自动收敛,空区间视为清除
  void setHighlight(int start, int end) {
    final len = text.length;
    final s = start.clamp(0, len);
    final e = end.clamp(0, len);
    highlight = s >= e ? null : TextRange(start: s, end: e);
    notifyListeners();
  }

  void clearHighlight() {
    if (highlight == null) return;
    highlight = null;
    notifyListeners();
  }

  /// 当前高亮的文字;区间失效返回 null
  String? get highlightedText {
    final h = highlight;
    if (h == null || h.end > text.length) return null;
    final t = text.substring(h.start, h.end);
    return t.trim().isEmpty ? null : t;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final h = highlight;
    // 输入法组合期间交给默认实现,避免 span 切分冲突
    if (h == null ||
        h.start >= text.length ||
        h.end > text.length ||
        (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(style: style, children: [
      if (h.start > 0) TextSpan(text: text.substring(0, h.start)),
      TextSpan(
          text: text.substring(h.start, h.end),
          style: TextStyle(backgroundColor: highlightColor)),
      if (h.end < text.length) TextSpan(text: text.substring(h.end)),
    ]);
  }
}
