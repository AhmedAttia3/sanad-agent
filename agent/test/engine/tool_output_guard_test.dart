import 'package:sanad_agent/engine/runtime/tool_output_guard.dart';
import 'package:test/test.dart';

void main() {
  group('ToolOutputGuard', () {
    test('keeps small results unchanged', () {
      expect(ToolOutputGuard.guardResult('small result'), 'small result');
    });

    test('truncates oversized results with head, tail, and size metadata', () {
      final result =
          '${List.filled(30000, 'H').join()}${List.filled(30000, 'T').join()}';

      final guarded = ToolOutputGuard.guardResult(result);

      expect(guarded.length, lessThanOrEqualTo(ToolOutputGuard.maxResultChars));
      expect(guarded, startsWith('H'));
      expect(guarded, endsWith('T'));
      expect(guarded, contains('TOOL OUTPUT TRUNCATED'));
      expect(guarded, contains('60000 characters'));
    });

    test('enforces an aggregate budget across multiple valid results', () {
      final guarded = ToolOutputGuard.guardBatch({
        'first': List.filled(45000, 'a').join(),
        'second': List.filled(45000, 'b').join(),
        'third': List.filled(45000, 'c').join(),
      });

      final total = guarded.values.fold<int>(
        0,
        (sum, value) => sum + value.length,
      );
      expect(total, lessThanOrEqualTo(ToolOutputGuard.maxBatchChars));
      expect(
        guarded.values.where((value) => value.contains('TRUNCATED')),
        isNotEmpty,
      );
    });
  });
}
