/// 全局页面上下文:悬浮球助手读取"当前界面内容"的注册表
library;

class PageSnapshot {
  const PageSnapshot({this.novelId, required this.detail});

  /// 当前页面所属小说;null 表示不在小说上下文中
  final int? novelId;

  /// 当前界面内容的文字描述(实时)
  final String detail;
}

typedef PageContextProvider = PageSnapshot Function();

/// 页面 initState 时 push 提供者,dispose 时 pop;栈顶即当前页面
class AppContextRegistry {
  static final _stack = <PageContextProvider>[];

  static void push(PageContextProvider p) => _stack.add(p);

  static void pop(PageContextProvider p) => _stack.remove(p);

  static PageSnapshot? snapshot() =>
      _stack.isEmpty ? null : _stack.last();
}
