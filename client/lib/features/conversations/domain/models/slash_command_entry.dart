import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

enum SlashCommandType {
  skill('skill')
  ;

  final String type;
  const SlashCommandType(this.type);
}

extension SlashCommandTypeX on SlashCommandType {
  IconData get icon {
    switch (this) {
      case SlashCommandType.skill:
        return Symbols.contract;
    }
  }
}

class SlashCommandEntry {
  final String sourceId;
  final String command;
  final String insertText;
  final String? description;
  final SlashCommandType type;

  const SlashCommandEntry({
    required this.sourceId,
    required this.command,
    required this.insertText,
    this.description,
    this.type = SlashCommandType.skill,
  });
}
