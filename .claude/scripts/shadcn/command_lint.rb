#!/usr/bin/env ruby
# frozen_string_literal: true

# Static lint of the port tooling's own documentation: commands, agents and skills reference scripts,
# flags, rake tasks, subcommands and files. Each reference must resolve, otherwise an orchestrating
# agent will be told to run something that does not exist.
#
#   ruby .claude/scripts/shadcn/command_lint.rb                 # lint the real commands/agents/skills
#   ruby .claude/scripts/shadcn/command_lint.rb --docs a.md b.md # lint only these files (used by the golden suite)
# Prints JSON { pass, checked, findings: [{ code, file, line, detail }] }; exit 1 on findings.
#
# Codes:
#   LINT_SCRIPT_MISSING   .claude/scripts/shadcn/<file> referenced but absent
#   LINT_FLAG_UNKNOWN     `--flag` used on a line with a script, but the script never defines it
#   LINT_SUBCOMMAND       `port_state.rb <sub>` not handled by the script
#   LINT_RAKE_MISSING     `bin/rails theme:<task>` not defined in lib/tasks/chadcn*.rake
#   LINT_REF_MISSING      `references/<file>.md` (or a skill path) that does not exist
#   LINT_AGENT_MISSING    agent name referenced as shadcn-* but no .claude/agents file
#   LINT_COMMAND_MISSING  /shadcn-* slash command referenced but no .claude/commands file

require "json"
require_relative "layout"

SCRIPTS_DIR = ".claude/scripts/shadcn"
DOC_GLOBS = %w[
  .claude/commands/shadcn-*.md
  .claude/agents/shadcn-*.md
  .ai/skills/shadcn-port/**/*.md
  .ai/skills/radix-stimulus/**/*.md
  .ai/skills/design-system/SKILL.md
  .ai/skills/design-system/references/compound-components.md
].freeze
# Flags that belong to other tools when they share a line with one of our scripts.
FOREIGN_FLAGS = %w[--yes --overwrite --force --port --strictPort --check-types --dry-run --no-checks --offline-cache --name-only --no-bootstrap --lazy].freeze

findings = []
checked = 0
add = ->(code, file, line, detail) { findings << { code: code, file: file, line: line, detail: detail } }

docs = ARGV.first == "--docs" ? ARGV.drop(1) : DOC_GLOBS.flat_map { |g| Dir[g] }.uniq.sort
script_sources = Dir[File.join(SCRIPTS_DIR, "*")].to_h { |f| [File.basename(f), File.read(f)] }
rake_tasks = Dir["#{ShadcnLayout::GEM_DIR}/lib/tasks/chadcn*.rake"].flat_map do |file|
  File.read(file).scan(/^\s*task\s+:(\w+)|^\s*task\s+(\w+):/).flatten.compact
end
agents = Dir[".claude/agents/shadcn-*.md"].map { |f| File.basename(f, ".md") }
commands = Dir[".claude/commands/shadcn-*.md"].map { |f| File.basename(f, ".md") }
port_state_subs = script_sources.fetch("port_state.rb", "").scan(/^when "(\w+)"/).flatten

docs.each do |doc|
  in_fence = false
  File.readlines(doc).each_with_index do |text, idx|
    n = idx + 1
    in_fence = !in_fence if text.start_with?("```")
    # Skip lines that describe things we intentionally say do not exist.
    next if text.match?(/\bdoes not exist\b|\bno longer\b|\bremoved\b/i)

    text.scan(%r{scripts/shadcn/([\w.-]+\.(?:rb|mjs))}).flatten.each do |file|
      checked += 1
      unless script_sources.key?(file)
        add.call("LINT_SCRIPT_MISSING", doc, n, file)
        next
      end
      # A flag is fine if ANY script named on the same line defines it (lines often chain two scripts).
      line_sources = text.scan(/\b([\w-]+\.(?:rb|mjs))\b/).flatten.uniq.filter_map { |f| script_sources[f] }
      flags = text.scan(/\s(--[a-zA-Z][\w-]*)/).flatten.uniq - FOREIGN_FLAGS
      flags.each do |flag|
        checked += 1
        add.call("LINT_FLAG_UNKNOWN", doc, n, "#{file} #{flag}") unless line_sources.any? { |src| src.include?(flag) }
      end
      if file == "port_state.rb"
        sub = text[/port_state\.rb\s+(\w+)/, 1]
        if sub
          checked += 1
          add.call("LINT_SUBCOMMAND", doc, n, "port_state.rb #{sub}") unless port_state_subs.include?(sub)
        end
      end
    end

    text.scan(/bin\/rails\s+theme:(\w+)/).flatten.each do |task|
      checked += 1
      add.call("LINT_RAKE_MISSING", doc, n, "theme:#{task}") unless rake_tasks.include?(task)
    end

    text.scan(%r{`references/([\w-]+\.md)`}).flatten.each do |ref|
      checked += 1
      candidates = Dir[".ai/skills/*/references/#{ref}"]
      add.call("LINT_REF_MISSING", doc, n, "references/#{ref}") if candidates.empty?
    end

    text.scan(%r{\.ai/skills/([\w-]+)/(?:SKILL\.md|references/([\w-]+\.md))}).each do |skill, ref|
      checked += 1
      path = ref ? ".ai/skills/#{skill}/references/#{ref}" : ".ai/skills/#{skill}/SKILL.md"
      add.call("LINT_REF_MISSING", doc, n, path) unless File.exist?(path)
    end

    text.scan(/\bshadcn-(?:port|parity)-[a-z]+\b/).uniq.each do |agent|
      checked += 1
      add.call("LINT_AGENT_MISSING", doc, n, agent) unless agents.include?(agent)
    end

    text.scan(%r{(?<![\w./-])/(shadcn-[a-z]+)(?![\w/-])}).flatten.each do |cmd|
      checked += 1
      add.call("LINT_COMMAND_MISSING", doc, n, "/#{cmd}") unless commands.include?(cmd)
    end
  end
end

puts JSON.pretty_generate(pass: findings.empty?, checked: checked, findings: findings)
exit(findings.empty? ? 0 : 1)
