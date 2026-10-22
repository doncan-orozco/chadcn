#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that a scenario file exercises everything the oracle manifest declares.
#   ruby .claude/scripts/shadcn/scenario_coverage.rb --component button [--oracle DIR] [--scenarios DIR]
# Exit 0 = covered, 1 = gaps. Prints JSON { component, pass, gaps: [{ code, detail }] }.

require_relative "layout"
require "json"
require "optparse"

opts = { oracle: ShadcnLayout::ORACLE_DIR, scenarios: ShadcnLayout::SCENARIOS_DIR, state: ShadcnLayout::STATE_FILE }
OptionParser.new do |o|
  o.on("--component NAME") { |v| opts[:component] = v }
  o.on("--oracle DIR") { |v| opts[:oracle] = v }
  o.on("--scenarios DIR") { |v| opts[:scenarios] = v }
  o.on("--state FILE") { |v| opts[:state] = v }
end.parse!
abort("usage: --component NAME") unless opts[:component]

manifest = JSON.parse(File.read(File.join(opts[:oracle], "manifest", "#{opts[:component]}.json")))
file = File.join(opts[:scenarios], "#{opts[:component]}.json")
gaps = []

unless File.exist?(file)
  puts JSON.pretty_generate(component: opts[:component], pass: false, gaps: [{ code: "SC_FILE_MISSING", detail: file }])
  exit 1
end

scenario_file = JSON.parse(File.read(file))
scenarios = scenario_file.fetch("scenarios")
ids = scenarios.map { |s| s["id"] }
(ids.tally.select { |_, n| n > 1 }.keys).each { |id| gaps << { code: "SC_DUPLICATE_ID", detail: id } }

nodes = lambda do |tree, acc = []|
  next acc unless tree.is_a?(Hash)

  acc << tree
  Array(tree["children"]).each { |c| nodes.call(c, acc) }
  acc
end

flat = scenarios.map { |s| [s, nodes.call(s["tree"])] }
exports = manifest["exports"]
# A scenario may compose the components this one depends on (DialogTrigger asChild > Button): their exports are valid too.
dependency_exports = manifest.fetch("registry_dependencies", []).flat_map do |dep|
  dep_file = File.join(opts[:oracle], "manifest", "#{dep}.json")
  File.exist?(dep_file) ? JSON.parse(File.read(dep_file))["exports"] : []
end

# Opt-in at file level: "composes" lets a renderless component (direction) wrap the consumers that show its effect.
MAX_COMPOSES = 8
composes = Array(scenario_file["composes"])
known = File.exist?(opts[:state]) ? JSON.parse(File.read(opts[:state])).fetch("components", {}).keys : []
gaps << { code: "SC_COMPOSES_INVALID", detail: "more than #{MAX_COMPOSES} names (#{composes.size})" } if composes.size > MAX_COMPOSES
composed_exports = composes.first(MAX_COMPOSES).flat_map do |name|
  manifest_file = File.join(opts[:oracle], "manifest", "#{name}.json")
  reason = if name == opts[:component] then "is the component itself"
  elsif !File.exist?(manifest_file) then "has no oracle manifest"
  elsif !known.include?(name) then "is not in state.json"
  end
  if reason
    gaps << { code: "SC_COMPOSES_INVALID", detail: "#{name} #{reason}" }
    next []
  end

  JSON.parse(File.read(manifest_file))["exports"]
end
dependency_exports += composed_exports

flat.each do |s, ns|
  ns.each { |n| gaps << { code: "SC_UNKNOWN_COMPONENT", detail: "#{s['id']}: #{n['c']}" } unless exports.include?(n["c"]) || dependency_exports.include?(n["c"]) || n["c"].to_s.start_with?("_") }
end

used_components = flat.flat_map { |_, ns| ns.map { |n| n["c"] } }.uniq
manifest["parts"].each do |part|
  next if part["name"].match?(/\A[a-z]/)
  next unless exports.include?(part["name"]) # a part the source does not export cannot appear in a tree (e.g. SheetPortal, SheetOverlay)

  gaps << { code: "SC_PART_UNUSED", detail: part["name"] } unless used_components.include?(part["name"])
end

cva_parts = manifest["parts"].select { |p| p["uses_cva"] }.map { |p| p["name"] }
manifest["cva"].each_value do |cva|
  first_axis = cva["variants"].keys.first
  cva["variants"].each do |axis, options|
    options.each_key do |opt|
      next if %w[true false].include?(opt)

      with_cva = flat.flat_map { |s, ns| ns.select { |n| cva_parts.include?(n["c"]) }.map { |n| [s, n] } }
      explicit = with_cva.any? { |_, n| n.dig("props", axis).to_s == opt }
      by_default = cva["defaults"][axis].to_s == opt && with_cva.any? { |_, n| !n.fetch("props", {}).key?(axis) }
      gaps << { code: "SC_VARIANT_UNCOVERED", detail: "#{axis}=#{opt}" } unless explicit || by_default
      next unless axis == first_axis

      dark = with_cva.any? { |s, n| s["dark"] && (n.dig("props", axis).to_s == opt || (cva["defaults"][axis].to_s == opt && !n.fetch("props", {}).key?(axis))) }
      gaps << { code: "SC_NO_DARK_TWIN", detail: "#{axis}=#{opt}" } unless dark
    end
  end
end

interactive = !%w[static].include?(manifest["tier"])
gaps << { code: "SC_NO_INTERACTION", detail: "tier #{manifest['tier']} needs scenarios with steps" } if interactive && scenarios.none? { |s| Array(s["steps"]).any? }

states = manifest["class_tokens"].flat_map { |t| t.scan(/data-\[state=([\w-]+)\]/).flatten }.uniq
if states.any? && scenarios.count { |s| Array(s["steps"]).any? } < [states.size, 1].max
  gaps << { code: "SC_STATES_THIN", detail: "oracle styles #{states.join(', ')}; fewer stepped scenarios than states" }
end

puts JSON.pretty_generate(component: opts[:component], pass: gaps.empty?, scenario_count: scenarios.size, gaps: gaps)
exit(gaps.empty? ? 0 : 1)
