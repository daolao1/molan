import 'package:flutter_test/flutter_test.dart';
import 'package:molan/data/writing_tools.dart';

void main() {
  test('punctuation and paragraph changes are always free', () {
    expect(polishRejection('他说你来了。', '他说:“你来了!”'), isNull);
    expect(polishRejection('他推门进来。屋里没人。', '他推门进来。\n\n屋里没人。'), isNull);
  });

  test('typos and trims stay within budget', () {
    expect(polishRejection('她的声音很底沉', '她的声音很低沉'), isNull);
    expect(polishRejection('他因为很累所以就坐在了那块石头的上面,休息。', '他累了,坐在那块石头上休息。'), isNull);
  });

  test('rewriting the sentence is rejected', () {
    final r = polishRejection('他走进屋子。', '暮色里,他推开那扇吱呀作响的木门,迟疑地迈了进去。');
    expect(r, isNotNull);
    expect(r, contains('失败'));
  });

  test('adding content is rejected even when the original is kept', () {
    final r = polishRejection('她站在窗前,看着外面。', '她站在窗前,看着外面漫天的大雪和空无一人的长街。');
    expect(r, isNotNull);
    expect(r, contains('增添内容'));
  });

  test('over-long fragments are rejected', () {
    final long = '字' * (polishMaxLen + 1);
    expect(polishRejection(long, long), contains('过长'));
  });

  test('pure-punctuation fragment does not blow up on ratio math', () {
    expect(polishRejection('……', '。'), isNull);
    // 只补一个漏字仍在 +2 的宽容里,成段添字照样挡下
    expect(polishRejection('——', '字'), isNull);
    expect(polishRejection('——', '好大的雪'), contains('增添内容'));
  });
}
