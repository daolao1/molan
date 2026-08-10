import 'package:flutter/material.dart';

import '../data/app_context.dart';
import '../data/change_set.dart';
import '../data/db.dart';
import '../data/entry_fields.dart';
import '../data/llm_client.dart';
import '../data/novel_tools.dart';
import '../data/prompts.dart';
import '../data/settings.dart';
import 'widgets.dart';

/// 全局悬浮球:读取当前界面上下文,按用户指令批量变更设定库
class AssistantBall extends StatefulWidget {
  const AssistantBall(
      {super.key, required this.db, required this.navKey, required this.smKey});

  final AppDatabase db;
  final GlobalKey<NavigatorState> navKey;
  final GlobalKey<ScaffoldMessengerState> smKey;

  @override
  State<AssistantBall> createState() => _AssistantBallState();
}

class _AssistantBallState extends State<AssistantBall> {
  Offset? _pos;
  bool _busy = false;

  void _toast(String msg, {bool error = false}) {
    widget.smKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
        duration: Duration(seconds: error ? 6 : 3),
      ));
  }

  Future<void> _open() async {
    final ctx = widget.navKey.currentContext;
    if (ctx == null) return;
    final snap = AppContextRegistry.snapshot();
    if (snap?.novelId == null) {
      _toast('打开一本小说后,我才能操作它的设定库', error: true);
      return;
    }
    final novel = await widget.db.novelById(snap!.novelId!);
    if (novel == null) return;
    if (!ctx.mounted) return;

    final promptCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('万能指令'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI 会阅读当前界面内容,按指令对《${novel.title}》的设定库做增/删/改,执行前需你逐项确认。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SubmitOnEnter(
              onSubmit: () => Navigator.pop(context, true),
              child: TextField(
                controller: promptCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '例:把正文里新出现的"青鳞剑"加入物品设定,Enter 执行',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('执行')),
        ],
      ),
    );
    final instruction = promptCtrl.text.trim();
    if (ok != true || instruction.isEmpty) return;

    setState(() => _busy = true);
    try {
      final settings = await SettingsStore.loadFor(LlmPurpose.lore);
      final all = await widget.db.allEntriesOf(novel.id);
      final links = await widget.db.linksOfNovel(novel.id);
      final userMsg = assistantChangesUser(
        novel: novel,
        allEntries: all,
        links: links,
        pageDetail: snap.detail,
        instruction: instruction,
      );
      String reply;
      try {
        reply = await LlmClient.chatWithTools(
          settings,
          system: assistantChangesSystem(withTools: true),
          user: userMsg,
          tools: novelToolSchemas,
          onToolCall: NovelToolExecutor(widget.db, novel.id).call,
        );
      } on ToolsUnsupportedException {
        reply = await LlmClient.chat(settings,
            system: assistantChangesSystem(), user: userMsg);
      }
      final changes = parseChanges(reply);
      final navCtx = widget.navKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      final approved = await _reviewChanges(navCtx, changes);
      if (approved == null || approved.isEmpty) return;
      final (okCount, failed) =
          await applyChanges(widget.db, novel.id, approved);
      _toast(failed.isEmpty
          ? '已应用 $okCount 项变更'
          : '应用 $okCount 项;失败:${failed.join(';')}');
    } on LlmException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('执行失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 审批弹窗:复选列表,点击看详情;返回选中的变更
  Future<List<EntryChange>?> _reviewChanges(
      BuildContext ctx, List<EntryChange> changes) {
    final selected = List.filled(changes.length, true);
    return showDialog<List<EntryChange>>(
      context: ctx,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('AI 建议 ${changes.length} 项变更'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: changes.length,
              itemBuilder: (context, i) {
                final c = changes[i];
                return CheckboxListTile(
                  value: selected[i],
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) =>
                      setDialogState(() => selected[i] = v ?? false),
                  title: Text('${c.actionLabel} [${c.kind.label}] ${c.name}'),
                  subtitle: Text(c.reason,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  secondary: IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    tooltip: '详情',
                    onPressed: () => _showDetail(context, c),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() {
                final all = selected.every((s) => s);
                for (var i = 0; i < selected.length; i++) {
                  selected[i] = !all;
                }
              }),
              child: const Text('全选/全不选'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(context, [
                for (var i = 0; i < changes.length; i++)
                  if (selected[i]) changes[i]
              ]),
              child: Text('应用选中(${selected.where((s) => s).length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext ctx, EntryChange c) {
    final labels = {
      for (final f in entryFieldsFor(c.kind)) f.key: f.label
    };
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text('${c.actionLabel} [${c.kind.label}] ${c.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.reason.isNotEmpty) ...[
                  Text('理由', style: Theme.of(context).textTheme.titleSmall),
                  Text(c.reason),
                  const SizedBox(height: 12),
                ],
                if (c.action == 'delete')
                  const Text('该条目将被删除,关联关系一并清理。')
                else ...[
                  Text('将写入的字段',
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final e in c.fields.entries) ...[
                    const SizedBox(height: 8),
                    Text(labels[e.key] ?? e.key,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary)),
                    SelectableText(e.value),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pos = _pos ??
        Offset(size.width - 72, size.height * 0.62);
    return Positioned(
      left: pos.dx.clamp(0, size.width - 56),
      top: pos.dy.clamp(0, size.height - 56),
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _pos = pos + d.delta),
        child: FloatingActionButton(
          heroTag: 'assistant_ball',
          mini: true,
          onPressed: _busy ? null : _open,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_fix_high),
        ),
      ),
    );
  }
}
