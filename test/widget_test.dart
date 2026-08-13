import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:molan/data/db.dart';
import 'package:molan/main.dart';

void main() {
  test('小节名称与情节编排可创建和更新', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final novelId = await db.createNovel('测试之书', '');
    final chapterId = await db.createChapter(novelId, '第一章');
    final sectionId = await db.createEvent(chapterId, '雪夜来客', '主角抵达客栈');

    var sections = await db.eventsOf(chapterId);
    expect(sections.single.name, '雪夜来客');
    await db.updateEvent(sectionId, name: '客栈相逢');
    sections = await db.eventsOf(chapterId);
    expect(sections.single.name, '客栈相逢');

    await db.replaceEventPlots(sectionId, novelId, [
      (id: null, name: '发现异常', description: '主角发现客栈里的客人都在暗中观察他'),
      (id: null, name: '身份试探', description: '陌生剑客借佩剑来历试探主角身份'),
    ]);
    var plots = await db.plotsOfEvent(sectionId);
    expect(plots.map((e) => e.name), ['发现异常', '身份试探']);

    await db.replaceEventPlots(sectionId, novelId, [
      (id: plots[1].id, name: '正面试探', description: '剑客说出旧事观察主角反应'),
    ]);
    plots = await db.plotsOfEvent(sectionId);
    expect(plots.single.name, '正面试探');
    expect((await db.allEntriesOf(novelId))
        .where((e) => e.kind == EntryKind.plot.name)
        .map((e) => e.name), ['正面试探']);
  });

  testWidgets('创建小说流程', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(MolanApp(db: db));
    await tester.pumpAndSettle();

    expect(find.text('墨澜'), findsOneWidget);
    expect(find.textContaining('还没有小说'), findsOneWidget);

    // 新建小说
    await tester.tap(find.text('新建小说'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '书名'), '测试之书');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('测试之书'), findsOneWidget);

    // 进入小说页,场景是独立顶层 Tab
    await tester.tap(find.text('测试之书'));
    await tester.pumpAndSettle();
    expect(find.text('人物'), findsOneWidget);
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('物品'), findsOneWidget);
    // TabBar 与右侧导航栏各出现一次
    expect(find.text('设定'), findsAtLeastNWidgets(1));
    expect(find.text('写作'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('情节'), findsNothing);

    // 新建人物
    await tester.tap(find.text('新建人物'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '人物名称 *'), '主角');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('主角'), findsOneWidget);

    // 卸载树并推进时钟,消化 drift 查询流的保活 timer
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
