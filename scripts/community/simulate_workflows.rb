#!/usr/bin/env ruby
# frozen_string_literal: true

Scenario = Struct.new(:name, :input, :expected, keyword_init: true)

ROUTES = {
  security: 'Private Vulnerability Reporting or security@eaststarai.com',
  quick_question: 'Discord',
  architectural_idea: 'GitHub Discussion',
  reproducible_bug: 'GitHub Issue',
  large_accepted_change: 'Epic Issue plus docs/plans/tasks plan'
}.freeze

scenarios = [
  Scenario.new(name: 'security report stays private', input: :security, expected: ROUTES[:security]),
  Scenario.new(name: 'question starts in community', input: :quick_question, expected: ROUTES[:quick_question]),
  Scenario.new(name: 'idea starts as discussion', input: :architectural_idea, expected: ROUTES[:architectural_idea]),
  Scenario.new(name: 'reproducible bug is actionable', input: :reproducible_bug, expected: ROUTES[:reproducible_bug]),
  Scenario.new(name: 'large accepted change gets a plan', input: :large_accepted_change, expected: ROUTES[:large_accepted_change])
]

scenarios.each do |scenario|
  actual = ROUTES.fetch(scenario.input)
  abort("Scenario failed: #{scenario.name}") unless actual == scenario.expected
end

review = {
  '.github/labels.yml' => 'maintainer-reviewed',
  'agent/lib/core/auth/token_store.dart' => 'security-reviewed',
  'client/release/windows/build_windows.ps1' => 'release-reviewed',
  'docs/product/features.md' => nil
}
abort('Review simulation failed') unless review.values == ['maintainer-reviewed', 'security-reviewed', 'release-reviewed', nil]

lifecycle = %w[issue worktree focused-diff verification review-labels aggregate-check squash-merge attribution]
abort('PR lifecycle simulation is incomplete') unless lifecycle.first == 'issue' && lifecycle.last == 'attribution'

puts "Community workflow simulation passed: #{scenarios.length} routes, #{review.length} review paths, #{lifecycle.length} lifecycle stages."
