import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:molan/data/db.dart';
import 'package:molan/data/llm_client.dart';
import 'package:molan/data/novel_tools.dart';
import 'package:molan/data/writing_tools.dart';

void main() {
  group('locateFragment 容错定位', () {
    test('逐字命中给出精确区间', () {
      const content = '他推门进来。屋里没人。';
      final m = locateFragment(content, '推门');
      expect(m.found, isTrue);
      expect(m.how, '逐字');
      expect(content.substring(m.start!, m.end!), '推门');
    });

    test('模型抄回 read_content 的行号前缀也能命中', () {
      const content = '第一行。\n第二行。';
      final m = locateFragment(content, '1| 第一行。\n2| 第二行。');
      expect(m.found, isTrue);
      expect(m.how, '忽略行号前缀');
      expect(content.substring(m.start!, m.end!), content);
    });

    test('分段与空白差异不影响定位', () {
      const content = '他推门进来。屋里没人。';
      final m = locateFragment(content, '他推门进来。\n\n屋里没人。');
      expect(m.found, isTrue);
      expect(m.how, '忽略空白与标点');
      // 片段自带的收尾标点一并纳入区间,替换后不会留下重复的"。""
      expect(content.substring(m.start!, m.end!), content);
    });

    test('引号全半角与逗号句号差异不影响定位', () {
      const content = '他说:“你来了。”';
      final m = locateFragment(content, '他说:"你来了."');
      expect(m.found, isTrue);
      expect(m.how, '忽略空白与标点');
    });

    test('多处命中时报出出现次数与行号,不猜', () {
      const content = '雪落了。\n\n雪落了。';
      final m = locateFragment(content, '雪落了。');
      expect(m.found, isFalse);
      expect(m.failure, contains('2 处'));
      expect(m.failure, contains('第 1、3 行'));
    });

    test('找不到时说清字数并给最接近的行', () {
      const content = '他站在窗前看着外面的大雪,一动不动。';
      final m = locateFragment(content, '他站在窗前看着外面的大雨');
      expect(m.found, isFalse);
      expect(m.failure, contains('正文中没有这段文字'));
      expect(m.failure, contains('最接近的是第 1 行'));
      expect(m.failure, contains('read_content'));
    });

    test('空片段被挡下', () {
      final m = locateFragment('正文', '   ');
      expect(m.found, isFalse);
    });
  });

  group('decodeToolArgsOrNull 参数保护', () {
    test('空参数与空对象放行(无参工具要用)', () {
      expect(LlmClient.decodeToolArgsOrNull(''), isEmpty);
      expect(LlmClient.decodeToolArgsOrNull('{}'), isEmpty);
      expect(LlmClient.decodeToolArgsOrNull(' { } '), isEmpty);
    });

    test('正常参数解析', () {
      expect(LlmClient.decodeToolArgsOrNull('{"a":1}')?['a'], 1);
    });

    test('拼接损坏的 JSON 判为协议损坏,不得执行', () {
      expect(LlmClient.decodeToolArgsOrNull('{"old_text":"残缺'), isNull);
      expect(LlmClient.decodeToolArgsOrNull('not json at all'), isNull);
    });
  });

  group('WritingToolExecutor 读写纪律', () {
    late AppDatabase db;
    late WritingToolExecutor ex;
    var content = '';
    var outline = '';

    WritingToolExecutor build(String initial) {
      content = initial;
      return WritingToolExecutor(
        readContent: () => content,
        writeContent: (v) => content = v,
        readOutline: () => outline,
        writeOutline: (v) => outline = v,
        highlight: (frag) => '已高亮',
        readHighlight: () => null,
        db: db,
        novelId: 1,
        lookup: NovelToolExecutor(db, 1),
      );
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      outline = '';
    });
    tearDown(() async {
      await db.close();
    });

    test('未读正文就改会被拦下并给出补救指令', () async {
      ex = build('他推门进来。');
      final r = await ex.call('replace_text', {'old_text': '推门', 'new_text': '踹门'});
      expect(r, startsWith('失败'));
      expect(r, contains('read_content'));
      expect(content, '他推门进来。');
    });

    test('读过之后用带行号前缀的原文也能改对', () async {
      ex = build('他推门进来。');
      await ex.call('read_content', {});
      final r = await ex.call(
          'replace_text', {'old_text': '1| 他推门进来。', 'new_text': '她推门进来。'});
      expect(r, startsWith('已替换'));
      expect(content, '她推门进来。');
    });

    test('标点差异的原文能改对并回报行号', () async {
      ex = build('他推门进来。\n屋里没人。');
      await ex.call('read_content', {});
      final r = await ex.call('replace_text',
          {'old_text': '他推门进来.\n屋里没人.', 'new_text': '他推门进来。\n屋里还是没人。'});
      expect(r, startsWith('已替换'));
      expect(r, contains('第 1 行'));
      expect(content, '他推门进来。\n屋里还是没人。');
    });

    test('read_content 给出字数统计', () async {
      ex = build('他推门进来。\n屋里没人。');
      final r = await ex.call('read_content', {});
      expect(r, contains('本节正文 11 字'));
      expect(r, contains('2 个自然段'));
    });

    test('append_text 回报追加字数与本节总字数', () async {
      ex = build('他推门进来。');
      final r = await ex.call('append_text', {'text': '屋里没人。'});
      expect(r, contains('已追加 5 字'));
      expect(r, contains('现 11 字'));
      expect(content, '他推门进来。\n\n屋里没人。');
    });

    test('set_content 大幅缩短且无理由被拒,写明理由才放行', () async {
      ex = build('字' * 200);
      await ex.call('read_content', {});
      final denied = await ex.call('set_content', {'text': '字' * 20});
      expect(denied, startsWith('失败'));
      expect(denied, contains('误删'));
      expect(content.length, 200);
      final ok = await ex.call(
          'set_content', {'text': '字' * 20, 'reason': '作者要求压缩成梗概'});
      expect(ok, startsWith('已重写全文'));
      expect(content.length, 20);
    });

    test('set_content 未经阅读直接拒绝', () async {
      ex = build('字' * 200);
      final r = await ex.call('set_content', {'text': '字' * 200});
      expect(r, startsWith('失败'));
      expect(r, contains('read_content'));
      expect(content.length, 200);
    });
  });

  group('proseCheckReport 正文体检', () {
    test('空正文给出空报告', () {
      expect(proseCheckReport('   '), contains('为空'));
    });

    test('数出字数、段数与最长段', () {
      final r = proseCheckReport('他推门进来。\n\n屋里没人。');
      expect(r, contains('字数 11'));
      expect(r, contains('自然段 2'));
    });

    test('命中套话并给出所在段号', () {
      final r = proseCheckReport('他推门进来。\n她不禁笑了。\n他仿佛听见了什么。');
      expect(r, contains('不禁'));
      expect(r, contains('第 2 段'));
      expect(r, contains('仿佛'));
      expect(r, contains('第 3 段'));
    });

    test('连续三段同起手被点出', () {
      final r = proseCheckReport('他站起来。\n他走过去。\n他推开门。');
      expect(r, contains('都以「他」起手'));
    });

    test('直述情绪与结尾升华被点出', () {
      final r = proseCheckReport('她很难过。\n\n或许这就是命运。');
      expect(r, contains('直述情绪'));
      expect(r, contains('升华'));
    });

    test('干净正文不误报', () {
      final r = proseCheckReport('门轴响了一声。\n\n来人没有抬头,只把茶碗往桌心推了推。');
      expect(r, contains('未发现套话'));
    });
  });

  group('offer_candidates 校验', () {
    late AppDatabase db;
    var content = '';
    WritingToolExecutor build(String initial) {
      content = initial;
      return WritingToolExecutor(
        readContent: () => content,
        writeContent: (v) => content = v,
        readOutline: () => '',
        writeOutline: (v) {},
        highlight: (f) => '',
        readHighlight: () => null,
        db: db,
        novelId: 1,
        lookup: NovelToolExecutor(db, 1),
      );
    }

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('少于两个版本被拒', () async {
      final ex = build('正文');
      final r = await ex.call('offer_candidates', {
        'mode': 'append',
        'candidates': [
          {'label': 'a', 'text': '只有一版'}
        ],
      });
      expect(r, startsWith('失败'));
    });

    test('replace 模式的 anchor 定位不到时被拒', () async {
      final ex = build('他推门进来。');
      final r = await ex.call('offer_candidates', {
        'mode': 'replace',
        'anchor': '根本不存在的一句',
        'candidates': [
          {'label': 'a', 'text': '第一版'},
          {'label': 'b', 'text': '第二版'},
        ],
      });
      expect(r, startsWith('失败'));
    });

    test('合格候选交给作者挑选,不自己落地', () async {
      final ex = build('他推门进来。');
      final r = await ex.call('offer_candidates', {
        'mode': 'append',
        'candidates': [
          {'label': '冷处理', 'text': '第一版正文'},
          {'label': '热冲突', 'text': '第二版正文'},
        ],
      });
      expect(r, contains('交给作者'));
      expect(content, '他推门进来。');
    });

    test('内容重复的候选被拒', () async {
      final ex = build('正文');
      final r = await ex.call('offer_candidates', {
        'mode': 'append',
        'candidates': [
          {'label': 'a', 'text': '同样的一段'},
          {'label': 'b', 'text': '同样的一段'},
        ],
      });
      expect(r, startsWith('失败'));
    });
  });
}
