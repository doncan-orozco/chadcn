#!/usr/bin/env ruby
# frozen_string_literal: true

# Reports which skill Quick Rules (R1..Rn) the /audit-feature pipeline has ever cited, and which
# skills are never loaded. Input: tmp/audit/rule-stats.jsonl, one JSON object per audit run:
#   {"at":"2026-10-08","scope":"branch-slug","skills_loaded":["controller"],"rules_cited":["controller R2"]}
# Usage: ruby .claude/scripts/audit_rule_coverage.rb [path/to/rule-stats.jsonl] [--min-runs N]

require "json"

root = File.expand_path("../..", __dir__)
stats_path = ARGV.reject { |a| a.start_with?("--") }.first || File.join(root, "tmp/audit/rule-stats.jsonl")
min_runs = (ARGV.each_cons(2).find { |a, _| a == "--min-runs" }&.last || 5).to_i

rules = {}
Dir[File.join(root, ".ai/skills/*/SKILL.md")].sort.each do |file|
  skill = File.basename(File.dirname(file))
  File.foreach(file) { |line| rules["#{skill} #{$1}"] = line.strip[0, 90] if line =~ /\A(R\d+)\./ }
end

runs = File.exist?(stats_path) ? File.readlines(stats_path).filter_map { |l| JSON.parse(l) rescue nil } : []
cited = runs.flat_map { |r| r["rules_cited"] || [] }.tally
loaded = runs.flat_map { |r| r["skills_loaded"] || [] }.tally
skills = rules.keys.map { |k| k.split.first }.uniq

puts "Audit runs recorded: #{runs.size} (#{stats_path})"
puts "Quick Rules defined: #{rules.size} across #{skills.size} skills"
if runs.size < min_runs
  puts "\nOnly #{runs.size} run(s); need >= #{min_runs} before 'never cited' is meaningful (--min-runs N to override)."
end

puts "\nSkills never loaded in any run (router never matched or budget guard dropped them):"
(skills - loaded.keys).each { |s| puts "  - #{s}" }

puts "\nRules never cited (candidate: too vague, never triggered, or skill not reaching the agents):"
(rules.keys - cited.keys).group_by { |k| k.split.first }.each do |skill, ids|
  puts "  #{skill}: #{ids.map { |i| i.split.last }.join(', ')}"
end

puts "\nMost cited:"
cited.sort_by { |_, n| -n }.first(10).each { |k, n| puts "  #{n.to_s.rjust(3)}  #{k}" }

unknown = cited.keys - rules.keys
puts "\nCited but not defined (typo or renumbered rule):\n  #{unknown.join(', ')}" unless unknown.empty?
