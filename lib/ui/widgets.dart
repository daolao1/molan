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
