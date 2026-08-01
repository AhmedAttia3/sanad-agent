import 'package:test/test.dart';
import 'package:sanad_agent/capabilities/models/local_tool_spec.dart';
import 'package:sanad_agent/capabilities/registry/tools_registry.dart';
import 'package:sanad_agent/capabilities/tools/base_tool.dart';
import 'package:sanad_agent/capabilities/tools/runtime/spec_backed_tool.dart';

class MockTool extends SpecBackedTool {
  @override
  LocalToolSpec get toolSpec => const LocalToolSpec(
    name: 'mock_tool',
    displayName: 'Mock Tool',
    description: 'A mock tool for testing',
    inputSchema: {},
    source: {'type': 'test', 'id': 'mock'},
    category: 'testing',
    workspaceRequired: false,
    approval: {'mode': 'default', 'sensitive': false},
    execution: {'target': 'local_runtime'},
  );
  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    return 'success: ${args['input'] ?? ''}';
  }
}

void main() {
  group('ToolsRegistry', () {
    late ToolsRegistry registry;
    late MockTool mockTool;

    setUp(() {
      registry = ToolsRegistry();
      mockTool = MockTool();
    });

    test('should register and retrieve a tool', () {
      registry.registerTool(mockTool);
      expect(registry.getTool('mock_tool'), equals(mockTool));
      expect(registry.getSpec('mock_tool')?.category, equals('testing'));
      expect(registry.allTools.length, 1);
    });

    test('should return null for non-existent tool', () {
      expect(registry.getTool('invalid'), isNull);
    });

    test('should execute tool through registry reference', () async {
      registry.registerTool(mockTool);
      final tool = registry.getTool('mock_tool');
      final result = await tool!.execute({'input': 'hello'});
      expect(result, 'success: hello');
    });

    test('should export an LLM-safe registration payload', () {
      registry.registerTool(mockTool);

      final payload = registry.toRegisterAllToolsPayload().single;

      expect(
        payload,
        equals({
          'name': 'mock_tool',
          'description': 'A mock tool for testing',
          'input_schema': <String, dynamic>{},
        }),
      );
      expect(payload.containsKey('approval'), isFalse);
      expect(payload.containsKey('permissions'), isFalse);
      expect(payload.containsKey('source'), isFalse);
      expect(payload.containsKey('execution'), isFalse);
    });

    test('should keep runtime metadata out of ToolSchema', () {
      final schema = mockTool.schema;

      expect(schema.name, 'mock_tool');
      expect(schema.description, 'A mock tool for testing');
      expect(schema.parameters, isEmpty);
      expect(schema.toJson().containsKey('approval'), isFalse);
      expect(schema.toJson().containsKey('permissions'), isFalse);
      expect(schema.toJson().containsKey('source'), isFalse);
      expect(schema.toJson().containsKey('execution'), isFalse);
    });
  });
}
