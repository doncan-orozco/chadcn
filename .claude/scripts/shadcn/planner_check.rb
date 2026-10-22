#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministic validation of one planner's output (spec + scenarios [+ deviations]).
# Used by /shadcn-plan and /shadcn-run after every planner receipt (never trust the receipt) and by
# the golden suite.
#
#   ruby .claude/scripts/shadcn/planner_check.rb --component badge [--root DIR] [--min-scenarios N]
#        [--require-dark] [--require-steps press,click,tab]
#
# --root DIR  repo-like root holding the port dir (layout.rb PORT_DIR) with {oracle,specs,scenarios,deviations} (default ".")
# Prints JSON { component, pass, findings: [{ code, detail }] }; exit 1 on findings.
#
# Codes:
#   P_SPEC_MISSING / P_SCENARIOS_MISSING   output file absent
#   P_SPEC_SECTION      required heading missing (API, Structure, Dependencies, Deviations; Behavior for non-static; Third-party for third_party)
#   P_SPEC_PART         an oracle part never named in the spec
#   P_SPEC_SLOT         an oracle data-slot never named in the spec
#   P_SCENARIOS_JSON    invalid JSON or wrong shape
#   P_SCENARIO_ID       duplicate or badly formed scenario id
#   P_PROP_NOT_REACT    scenario prop in snake_case or `class` (must be React names: className, asChild, defaultValue...)
#   P_STEP_INVALID      unknown `do`, or a step missing its required target/key/text
#   P_TOO_FEW           fewer scenarios than the cva options + required states imply
#   P_NO_DARK / P_STEP_KIND   golden-only requirements not met
#   SC_*                everything scenario_coverage.rb reports
#   P_DEVIATIONS        deviations file present but invalid or without a reason

require_relative "layout"
require "json"
require "open3"
require "optparse"

opts = { root: ".", min: nil, require_dark: false, steps: [] }
OptionParser.new do |o|
  o.on("--component NAME") { |v| opts[:component] = v }
  o.on("--root DIR") { |v| opts[:root] = v }
  o.on("--min-scenarios N", Integer) { |v| opts[:min] = v }
  o.on("--require-dark") { opts[:require_dark] = true }
  o.on("--require-steps LIST") { |v| opts[:steps] = v.split(",") }
end.parse!
abort("usage: --component NAME") unless opts[:component]

name = opts[:component]
base = ShadcnLayout.under(opts[:root], ShadcnLayout::PORT_DIR)
manifest = JSON.parse(File.read(File.join(base, "oracle/manifest/#{name}.json")))
findings = []
add = ->(code, detail) { findings << { code: code, detail: detail } }

STEP_REQUIRES = { "click" => :target, "dblclick" => :target, "hover" => :target, "focus" => :target, "fill" => :target,
                  "press" => :key, "type" => :text, "wait" => :ms, "mousedown" => nil, "mouseup" => nil, "tab" => nil, "viewport" => :width, "snapshot" => nil }.freeze

# ---- spec -----------------------------------------------------------------------------------
spec_file = File.join(base, "specs/#{name}.md")
if File.exist?(spec_file)
  spec = File.read(spec_file)
  heading = ->(title) { spec.match?(/^\#{1,3}\s*#{Regexp.escape(title)}\b/i) }
  required = %w[API Structure Dependencies Deviations]
  required << "Behavior" unless manifest["tier"] == "static"
  required << "Third-party" if manifest["tier"] == "third_party"
  required.each { |h| add.call("P_SPEC_SECTION", h) unless heading.call(h) }

  root = name.split("-").map(&:capitalize).join
  manifest["parts"].each do |part|
    next if part["name"].match?(/\A[a-z]/)

    short = part["name"].start_with?(root) && part["name"] != root ? part["name"].delete_prefix(root) : part["name"]
    add.call("P_SPEC_PART", part["name"]) unless spec.include?(part["name"]) || spec.include?("::#{short}")
  end
  manifest["data_slots"].each { |slot| add.call("P_SPEC_SLOT", slot) unless spec.include?(slot) }
else
  add.call("P_SPEC_MISSING", spec_file)
end

# ---- scenarios ------------------------------------------------------------------------------
sc_file = File.join(base, "scenarios/#{name}.json")
scenarios = []
if File.exist?(sc_file)
  begin
    data = JSON.parse(File.read(sc_file))
    scenarios = data.fetch("scenarios")
    add.call("P_SCENARIOS_JSON", "component is #{data['component'].inspect}, expected #{name.inspect}") unless data["component"] == name
    add.call("P_SCENARIOS_JSON", "scenarios must be a non-empty array") if !scenarios.is_a?(Array) || scenarios.empty?
  rescue JSON::ParserError, KeyError => e
    add.call("P_SCENARIOS_JSON", e.message[0, 120])
    scenarios = []
  end
else
  add.call("P_SCENARIOS_MISSING", sc_file)
end

ids = scenarios.map { |s| s["id"].to_s }
(ids.tally.select { |_, n| n > 1 }.keys).each { |i| add.call("P_SCENARIO_ID", "duplicate #{i}") }
ids.each { |i| add.call("P_SCENARIO_ID", "bad id #{i.inspect}") unless i.match?(/\A[a-z0-9]+(?:(?:__|-|_)[a-z0-9]+)*\z/) }

walk = lambda do |tree, &blk|
  next unless tree.is_a?(Hash)

  blk.call(tree)
  Array(tree["children"]).each { |c| walk.call(c, &blk) }
end

scenarios.each do |s|
  walk.call(s["tree"]) do |node|
    (node["props"] || {}).each_key do |k|
      next unless k.match?(/_/) || k == "class"
      next if k.start_with?("data-", "aria-")

      add.call("P_PROP_NOT_REACT", "#{s['id']}: #{node['c']} prop #{k.inspect}")
    end
  end
  Array(s["steps"]).each_with_index do |step, i|
    kind = step["do"]
    unless STEP_REQUIRES.key?(kind)
      add.call("P_STEP_INVALID", "#{s['id']} step #{i}: unknown do=#{kind.inspect}")
      next
    end
    need = STEP_REQUIRES[kind]
    add.call("P_STEP_INVALID", "#{s['id']} step #{i}: #{kind} needs #{need}") if need && step[need.to_s].to_s.empty? && step[need.to_s].nil?
  end
end

# ---- volume and coverage ---------------------------------------------------------------------
cva_options = manifest["cva"].values.sum { |c| c["variants"].values.sum { |v| v.keys.reject { |k| %w[true false].include?(k) }.size } }
needed = [opts[:min], 5, cva_options].compact.max
add.call("P_TOO_FEW", "#{scenarios.size} scenarios, expected at least #{needed}") if scenarios.any? && scenarios.size < needed

if opts[:require_dark] && scenarios.none? { |s| s["dark"] }
  add.call("P_NO_DARK", "no scenario with dark: true")
end
opts[:steps].each do |kind|
  add.call("P_STEP_KIND", "no scenario uses a #{kind} step") unless scenarios.any? { |s| Array(s["steps"]).any? { |st| st["do"] == kind } }
end

if File.exist?(sc_file)
  out, = Open3.capture2("ruby", File.join(File.dirname(__FILE__), "scenario_coverage.rb"), "--component", name,
                        "--oracle", File.join(base, "oracle"), "--scenarios", File.join(base, "scenarios"))
  JSON.parse(out)["gaps"].each { |g| add.call(g["code"], g["detail"]) } rescue add.call("P_SCENARIOS_JSON", "scenario_coverage.rb crashed")
end

dev_file = File.join(base, "deviations/#{name}.json")
if File.exist?(dev_file)
  begin
    dev = JSON.parse(File.read(dev_file))
    add.call("P_DEVIATIONS", "missing reason") if dev["reason"].to_s.strip.empty?
  rescue JSON::ParserError
    add.call("P_DEVIATIONS", "invalid JSON")
  end
end

puts JSON.pretty_generate(component: name, pass: findings.empty?, scenario_count: scenarios.size, findings: findings)
exit(findings.empty? ? 0 : 1)
