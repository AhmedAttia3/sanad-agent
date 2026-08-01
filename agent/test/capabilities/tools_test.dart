import 'package:test/test.dart';
import 'package:sanad_agent/capabilities/registry/tools_registry.dart';
import 'package:sanad_agent/capabilities/tools/delegate_task_tool.dart';

void main() {
  group('Capabilities Tests', () {
    late ToolsRegistry registry;

    setUp(() {
      registry = ToolsRegistry();
    });

    test('Register and retrieve tool', () {
      final tool = DelegateTaskTool();
      registry.registerTool(tool);

      final retrieved = registry.getTool('delegate_task');
      expect(retrieved, isNotNull);
      expect(retrieved?.schema.name, 'delegate_task');
    });

    test('DelegateTaskTool execution', () async {
      final tool = DelegateTaskTool();
      final result = await tool.execute({});

      expect(result, isNotEmpty);
    });
  });
}
