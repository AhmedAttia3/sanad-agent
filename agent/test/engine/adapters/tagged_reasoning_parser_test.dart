import 'package:sanad_agent/engine/adapters/tagged_reasoning_parser.dart';
import 'package:test/test.dart';

void main() {
  group('TaggedReasoningStreamParser', () {
    test(
      'streams reasoning while separating a tag split across arbitrary chunks',
      () {
        final parser = TaggedReasoningStreamParser();

        expect(parser.add('<thi').content, isNull);
        expect(parser.add('nk>Plan').reasoning, 'Plan');
        expect(parser.add('</thi').reasoning, isNull);
        expect(parser.add('nk>Answer').content, 'Answer');
        expect(parser.add(' continues').content, ' continues');

        final result = parser.finish();
        expect(result.reasoning, isNull);
        expect(result.content, isNull);
      },
    );

    test('streams reasoning from split mm:think tags (MiniMax)', () {
      final parser = TaggedReasoningStreamParser();

      expect(parser.add('<mm:thi').content, isNull);
      expect(parser.add('nk>MiniMax Plan').reasoning, 'MiniMax Plan');
      expect(parser.add('</mm:thi').reasoning, isNull);
      expect(parser.add('nk>MiniMax Answer').content, 'MiniMax Answer');

      final result = parser.finish();
      expect(result.reasoning, isNull);
      expect(result.content, isNull);
    });

    test('keeps an unclosed leading reasoning block out of final content', () {
      final parser = TaggedReasoningStreamParser();

      final streamed = parser.add('<think>Still deciding');
      final result = parser.finish();

      expect(streamed.reasoning, 'Still deciding');
      expect(streamed.content, isNull);
      expect(result.reasoning, isNull);
      expect(result.content, isNull);
    });

    test('passes ordinary text through without buffering later chunks', () {
      final parser = TaggedReasoningStreamParser();

      expect(parser.add('Visible ').content, 'Visible ');
      expect(parser.add('answer').content, 'answer');
      expect(parser.finish().content, isNull);
    });
  });
}
