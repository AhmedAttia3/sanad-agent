class MemoryContentScanner {
  static final List<({String id, RegExp pattern})> _patterns = [
    (
      id: 'prompt_injection',
      pattern: RegExp(
        r'\bignore\b.{0,40}\b(?:previous|prior|all|system)\b.{0,30}\binstructions?\b',
        caseSensitive: false,
      ),
    ),
    (
      id: 'disregard_rules',
      pattern: RegExp(
        r'\bdisregard\b.{0,40}\b(?:rules?|instructions?)\b',
        caseSensitive: false,
      ),
    ),
    (
      id: 'system_prompt_override',
      pattern: RegExp(
        r'\b(?:override|replace|rewrite)\b.{0,30}\bsystem\s+prompt\b|\bsystem\s+prompt\s+override\b',
        caseSensitive: false,
      ),
    ),
    (
      id: 'context_exfiltration',
      pattern: RegExp(
        r'\b(?:output|reveal|share|send)\b.{0,35}\b(?:system prompt|conversation history|entire context|full context)\b',
        caseSensitive: false,
      ),
    ),
    (
      id: 'remote_exfiltration',
      pattern: RegExp(
        r'\b(?:curl|wget|send|upload|post)\b.{0,80}https?://',
        caseSensitive: false,
      ),
    ),
    (
      id: 'persistence_attempt',
      pattern: RegExp(
        r'\b(?:write|append|install|add)\b.{0,50}(?:authorized_keys|\.ssh/|launchd|crontab)',
        caseSensitive: false,
      ),
    ),
    (
      id: 'agent_config_mutation',
      pattern: RegExp(
        r'\b(?:write|edit|modify|replace|update)\b.{0,40}(?:AGENTS\.md|CLAUDE\.md|SOUL\.md|\.cursorrules)',
        caseSensitive: false,
      ),
    ),
    (
      id: 'hardcoded_secret',
      pattern: RegExp(
        r'''\b(?:api[_ -]?key|access[_ -]?token|password|secret)\b\s*[:=]\s*["']?[A-Za-z0-9_\-]{16,}|\bsk-[A-Za-z0-9_\-]{16,}''',
        caseSensitive: false,
      ),
    ),
    (
      id: 'hidden_markup',
      pattern: RegExp(
        r'<!--.{0,300}(?:ignore|override|instruction|system prompt).{0,300}-->|<[^>]+display\s*:\s*none[^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
    ),
  ];

  static final RegExp _invisibleUnicode = RegExp(
    '[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );

  static List<String> scan(String content) {
    final findings = <String>[];
    if (_invisibleUnicode.hasMatch(content)) {
      findings.add('invisible_unicode');
    }
    for (final candidate in _patterns) {
      if (candidate.pattern.hasMatch(content)) {
        findings.add(candidate.id);
      }
    }
    return List<String>.unmodifiable(findings);
  }

  static String? rejectionMessage(String content) {
    final findings = scan(content);
    if (findings.isEmpty) {
      return null;
    }
    return 'Entry blocked because it contains unsafe persistent-prompt content '
        '(${findings.join(', ')}).';
  }
}
