import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';

class SkillLoadToolTile extends StatefulWidget {
  final CanonicalEvent event;

  const SkillLoadToolTile({
    super.key,
    required this.event,
  });

  @override
  State<SkillLoadToolTile> createState() => _SkillLoadToolTileState();
}

class _SkillLoadToolTileState extends State<SkillLoadToolTile> {
  bool _isExpanded = false;

  Map<String, dynamic> _parseInput(dynamic input) {
    if (input is Map<String, dynamic>) return input;
    if (input is Map) return Map<String, dynamic>.from(input);
    if (input is String) {
      try {
        final decoded = jsonDecode(input);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.status == EventStatus.running) {
      return _buildRunningIndicator(context);
    }

    if (widget.event.status == EventStatus.error) {
      return _buildErrorState(context);
    }

    final mapInput = _parseInput(widget.event.toolInput);
    final skillName = mapInput['skill']?.toString() ?? 'Skill';
    final skillArgs = mapInput['args']?.toString();
    final output = widget.event.toolOutput?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loaded Skill: $skillName',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (skillArgs != null && skillArgs.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Arguments: $skillArgs',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && output.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: SelectableText(
                  output,
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRunningIndicator(BuildContext context) {
    final mapInput = _parseInput(widget.event.toolInput);
    final skillName = mapInput['skill']?.toString() ?? 'skill';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading skill "$skillName"...',
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.event.toolOutput?.toString() ?? 'Failed to load skill.',
        style: GoogleFonts.roboto(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
