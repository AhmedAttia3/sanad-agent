import 'package:json_annotation/json_annotation.dart';

part 'tool_schema.g.dart';

@JsonSerializable(explicitToJson: true)
class ToolSchema {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  ToolSchema({
    required this.name,
    required this.description,
    required this.parameters,
  });

  factory ToolSchema.fromJson(Map<String, dynamic> json) =>
      _$ToolSchemaFromJson(json);
  Map<String, dynamic> toJson() => _$ToolSchemaToJson(this);
}
