import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:molan/data/db.dart';
import 'package:molan/main.dart';

void main() {
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

