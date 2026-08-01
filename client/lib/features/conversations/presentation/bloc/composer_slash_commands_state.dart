import 'package:equatable/equatable.dart';

import 'package:sanad_client/features/conversations/domain/models/slash_command_entry.dart';
import 'package:sanad_client/features/conversations/presentation/utils/skill_composer_utils.dart';

class ComposerSlashCommandsState extends Equatable {
  final List<SlashCommandEntry> availableEntries;
  final List<SlashCommandEntry> visibleEntries;
  final SkillSlashQuery? activeQuery;
  final int highlightedIndex;

  const ComposerSlashCommandsState({
    this.availableEntries = const [],
    this.visibleEntries = const [],
    this.activeQuery,
    this.highlightedIndex = 0,
  });

  ComposerSlashCommandsState copyWith({
    List<SlashCommandEntry>? availableEntries,
    List<SlashCommandEntry>? visibleEntries,
    SkillSlashQuery? activeQuery,
    int? highlightedIndex,
    bool clearActiveQuery = false,
  }) {
    return ComposerSlashCommandsState(
      availableEntries: availableEntries ?? this.availableEntries,
      visibleEntries: visibleEntries ?? this.visibleEntries,
      activeQuery: clearActiveQuery ? null : activeQuery ?? this.activeQuery,
      highlightedIndex: highlightedIndex ?? this.highlightedIndex,
    );
  }

  @override
  List<Object?> get props => [
    availableEntries,
    visibleEntries,
    activeQuery?.slashIndex,
    activeQuery?.cursorIndex,
    activeQuery?.query,
    highlightedIndex,
  ];
}
