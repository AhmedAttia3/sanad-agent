// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolSchema _$ToolSchemaFromJson(Map<String, dynamic> json) => ToolSchema(
  name: json['name'] as String,
  description: json['description'] as String,
  parameters: json['parameters'] as Map<String, dynamic>,
);

Map<String, dynamic> _$ToolSchemaToJson(ToolSchema instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'parameters': instance.parameters,
    };
