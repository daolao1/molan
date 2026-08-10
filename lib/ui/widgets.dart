import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// 带持久高亮的正文控制器:高亮区间独立于选区,失焦仍然渲染
class HighlightController extends TextEditingController {
  HighlightController({super.text});

  /// 当前钉住的高亮(字符区间);null 表示无
  TextRange? highlight;

  Color highlightColor = const Color(0x33FFC107);

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

  /// 文本被程序性改写后,尝试按原文片段重新定位高亮
  void relocateHighlight(String fragment) {
    if (fragment.isEmpty) return clearHighlight();
    final idx = text.indexOf(fragment);
    if (idx < 0) return clearHighlight();
    highlight = TextRange(start: idx, end: idx + fragment.length);
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
