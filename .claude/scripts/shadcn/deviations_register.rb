#!/usr/bin/env ruby
# frozen_string_literal: true

# Keeps the deviations register (layout.rb DEVIATIONS_REGISTER) in sync with the deviations/*.json files so the G5 house check
# (every deviations file must be registered) holds. Idempotent; preserves a human-entered `approved-by` value.
#
#   ruby .claude/scripts/shadcn/deviations_register.rb [--root DIR]
# Prints JSON { registered: [...], removed: [...] }.

require_relative "layout"
require "json"
require "optparse"

root = "."
OptionParser.new { |o| o.on("--root DIR") { |v| root = v } }.parse!
base = ShadcnLayout.under(root, ShadcnLayout::PORT_DIR)
register = ShadcnLayout.under(root, ShadcnLayout::DEVIATIONS_REGISTER)

approved = {}
if File.exist?(register)
  File.readlines(register).each do |line|
    cells = line.split("|").map(&:strip)
    next unless cells.size >= 6 && cells[1].match?(/\A`[\w-]+`\z/)

    approved[cells[1].delete("`")] = cells[4]
  end
end

rows = Dir[File.join(base, "deviations/*.json")].sort.filter_map do |file|
  name = File.basename(file, ".json")
  dev = JSON.parse(File.read(file))
  api = Array(dev["api"]).join(", ")
  tokens = (Array(dev["allow_tokens"]) + Array(dev["allow_missing_tokens"])).size
  what = [("API: #{api}" unless api.empty?), ("#{tokens} allowed class token(s)" if tokens.positive?)].compact.join("; ")
  reason = dev["reason"].to_s.strip.gsub(/\s+/, " ").gsub("|", "/")
  [name, what.empty? ? "(see file)" : what, reason, approved.fetch(name, "pending")]
end

body = rows.map { |n, w, r, a| "| `#{n}` | #{w} | #{r} | #{a} |" }
File.write(register, <<~MD)
  # shadcn port: deviations

  Every difference from the React original that the gates are told to accept. Generated from `deviations/*.json` by
  `.claude/scripts/shadcn/deviations_register.rb`; edit only the `approved-by` column.

  | component | deviation | reason | approved-by |
  |---|---|---|---|
  #{body.join("\n").gsub("\n", "\n  ")}
MD

previous = approved.keys
puts JSON.generate(registered: rows.map(&:first), removed: previous - rows.map(&:first))
