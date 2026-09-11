import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:molan/data/db.dart';
import 'package:molan/data/entry_fields.dart';
import 'package:molan/data/prompts.dart';

void main() {
  late AppDatabase db;
  late Novel novel;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final id = await db.createNovel('测试小说', '一句话简介');
    novel = (await db.novelById(id))!;
  });
  tearDown(() async => db.close());

  Future<Entry> loreCard(int novelId, String name, String detail) async {
    final id = await db.createEntry(novelId, EntryKind.lore,
        name, encodeEntryContent({'detail': detail}));
    return (await db.allEntriesOf(novelId)).firstWhere((e) => e.id == id);
  }

  test('写作 system 含流程、候选规则、文笔手册与事实快照', () async {
    final entry = await loreCard(novel.id, '文风', '短句为主,少用形容词');
    final s = writingAgentSystem(
      novel: novel,
      allEntries: [entry],
      links: const [],
      chapterTitle: '第一章',
      sectionName: '雪夜',
      sectionPlots: const ['主角被退婚:开场即冲突'],
      priorOutlines: const ['抵达边城'],
      followingOutlines: const ['入城受阻'],
      prevContentTail: '雪落在刀鞘上。',
      outline: '主角在雪夜遇袭',
      styleEntries: [entry],
    );
    expect(s, contains('【推进方式】'));
    expect(s, contains('check_prose'));
    expect(s, contains('【出候选】'));
    expect(s, contains('offer_candidates'));
    expect(s, contains('【文笔手册】'));
    expect(s, contains('【交稿前自检】'));
    expect(s, contains('【挂载设定】'));
    expect(s, contains('短句为主,少用形容词'));
    expect(s, contains('【本章此前小节大纲】'));
    expect(s, contains('雪落在刀鞘上。'));
    expect(s, contains('主角在雪夜遇袭'));
    // 润色口径统一:只走 polish_text
    expect(s, contains('润色这条路只有 polish_text'));
  });

  test('没有挂载设定时不出现挂载段落', () async {
    final s = writingAgentSystem(
      novel: novel,
      allEntries: const [],
      links: const [],
      chapterTitle: '第一章',
      sectionName: '',
      priorOutlines: const [],
      prevContentTail: '',
      outline: '',
    );
    expect(s, isNot(contains('【挂载设定】')));
    expect(s, contains('(未命名)'));
    expect(s.contains('(暂无任何设定)'), isTrue);
  });
}
