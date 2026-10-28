#!/usr/bin/env ruby
# frozen_string_literal: true

# Browser gates for a list of components in one call: ensures Playwright and the dev servers, runs G2/G3 for each component
# (and, on request, G2b DX helpers and G4 themes), writes the raw reports and stops the servers it started.
#
#   ruby .claude/scripts/shadcn/parity_batch.rb --components button,card          # G2 + G3
#   ruby .claude/scripts/shadcn/parity_batch.rb --components all --dx --themes slate,stone,zinc-radius0
#   ruby .claude/scripts/shadcn/parity_batch.rb --components all --dx --themes        # the same: the default presets
#   ruby .claude/scripts/shadcn/parity_batch.rb --components dialog --no-servers   # servers already running (servers.rb status)
#
# --components LIST|all  comma list of component names (each needs a scenario file), or every scenario file not starting with `_`
# --dx                   also G2b: scenarios starting default / variant- / example__ (cap 25) through the yielded-root helpers,
#                        only for components that have helpers (spec_helpers.rb --print)
# --themes [LIST]        also G4: each theme preset on the scenarios starting variant- or default (cap 12), plus one --dark run;
#                        without a list: slate,stone,zinc-radius0
# --no-servers           neither ensure Playwright nor start/stop servers (they must already be running)
# --only PREFIXES        comma list of scenario id prefixes: G2/G2b/G4 run only the scenarios whose id starts with one of them (cartesian__,
#                        polar__ for a chart family); the other ids are reported as skipped with the reason
# --out DIR              reports go to DIR/<component>/{g2,g2b,g4-<theme>,g4-dark}.json (default: layout.rb TMP_DIR, tmp/shadcn-port)
#
# Prints JSON { pass, servers_started, components: { name => { pass, gates => { gate => { pass, diffs } | { skipped } },
#   skipped_scenarios => { count, reason } (only with --only, when it left scenario ids out) } } }.
# Exit 0 every gate passed, 1 a gate found diffs, 2 the environment or the arguments are unusable (no browser, servers down,
# a gate crashed without a report, unknown component, an empty --only or one matching no scenario of the requested components).
# Servers this run started are always stopped, also on a failed start.

require_relative "layout"
require "fileutils"
require "json"
require "open3"
require "optparse"

ROOT = File.expand_path("../../..", __dir__)

SCRIPTS = ".claude/scripts/shadcn"
SCENARIOS = ShadcnLayout::SCENARIOS_DIR
CATALOG = ShadcnLayout::CATALOG_DIR
NAME_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/
DEFAULT_THEMES = %w[slate stone zinc-radius0].freeze
DX_PREFIXES = %w[default variant- example__].freeze
THEME_PREFIXES = %w[variant- default].freeze

class EnvironmentFailure < StandardError; end

def environment_failure(message, servers_started: false)
  puts JSON.pretty_generate(pass: false, servers_started: servers_started, error: message)
  exit 2
end

def parse_options(argv)
  options = { components: nil, dx: false, themes: [], servers: true, only: [], out: ShadcnLayout::TMP_DIR }
  OptionParser.new do |parser|
    parser.banner = "usage: parity_batch.rb --components a,b|all [--dx] [--themes [LIST]] [--only PREFIXES] [--no-servers] [--out DIR]"
    parser.on("--components LIST", "comma list of components, or all (scenario files not starting with _)") { |value| options[:components] = value }
    parser.on("--dx", "also G2b through the yielded-root helpers") { options[:dx] = true }
    parser.on("--themes [LIST]", "also G4 for each theme preset plus one --dark run (default presets: #{DEFAULT_THEMES.join(',')})") do |value|
      options[:themes] = value ? value.split(",").map(&:strip).reject(&:empty?).uniq : DEFAULT_THEMES.dup
    end
    parser.on("--no-servers", "servers already running; do not ensure Playwright or start/stop servers") { options[:servers] = false }
    parser.on("--only PREFIXES", "run only scenarios whose id starts with one of these comma separated prefixes") do |value|
      options[:only] = value.split(",").map(&:strip).reject(&:empty?).uniq
      raise OptionParser::InvalidArgument, "--only needs at least one non-empty prefix" if options[:only].empty?
    end
    parser.on("--out DIR", "report directory (default #{ShadcnLayout::TMP_DIR})") { |value| options[:out] = value }
  end.parse!(argv)
  options
rescue OptionParser::ParseError => e
  environment_failure(e.message)
end

def component_names(options)
  names =
    if options[:components] == "all"
      Dir[File.join(SCENARIOS, "*.json")].map { |file| File.basename(file, ".json") }.reject { |name| name.start_with?("_") }.sort
    else
      options[:components].to_s.split(",").map(&:strip).reject(&:empty?).uniq
    end
  environment_failure("usage: --components a,b|all [--dx] [--themes slate,stone] [--only PREFIXES] [--no-servers] [--out DIR]") if names.empty?

  invalid = (names + options[:themes]).grep_v(NAME_PATTERN)
  environment_failure("invalid name(s): #{invalid.join(', ')}") if invalid.any?

  unknown = names.reject { |name| File.exist?(File.join(SCENARIOS, "#{name}.json")) }
  environment_failure("no scenario file for: #{unknown.join(', ')}") if unknown.any?

  if options[:only].any? && names.none? { |name| all_scenario_ids(name).any? { |id| matches_prefix?(id, options[:only]) } }
    environment_failure("--only #{options[:only].join(',')} matches no scenario id of: #{names.join(', ')}")
  end
  names
end

def all_scenario_ids(component)
  JSON.parse(File.read(File.join(SCENARIOS, "#{component}.json"))).fetch("scenarios", []).filter_map { |scenario| scenario["id"] }
end

def matches_prefix?(id, prefixes)
  prefixes.any? { |prefix| id.start_with?(prefix) }
end

def scenario_ids(component, prefixes, cap)
  all_scenario_ids(component).select { |id| matches_prefix?(id, prefixes) }.first(cap)
end

# [ids to run, ids left out] for the --only prefixes; no prefixes selects everything.
def split_by_prefix(ids, prefixes)
  return [ ids, [] ] if prefixes.empty?

  ids.partition { |id| matches_prefix?(id, prefixes) }
end

def skipped_note(skipped, prefixes)
  { "count" => skipped.size, "reason" => "id does not start with --only #{prefixes.join(',')}" }
end

def only_reason(prefixes)
  prefixes.any? ? " among the --only #{prefixes.join(',')} scenarios" : ""
end

def run_tool(*command, **spawn_options)
  Open3.capture3(*command, **spawn_options)
rescue SystemCallError => e
  raise EnvironmentFailure, "cannot run #{command.first(2).join(' ')}: #{e.message}"
end

# The whole stdout is the report (parity_run.mjs and spec_helpers.rb print one JSON document); nil when it is not JSON.
def parse_report(stdout)
  JSON.parse(stdout)
rescue JSON::ParserError
  nil
end

def helpers?(component)
  stdout, stderr, status = run_tool("ruby", File.join(SCRIPTS, "spec_helpers.rb"), "--print", "--component", component)
  return false if status.success? && stdout.strip.empty? # the component has no nested parts
  raise EnvironmentFailure, "spec_helpers.rb --print #{component} failed: #{stderr.lines.last(3).join.strip}" unless status.success?

  Array(parse_report(stdout)&.fetch("helpers", nil)).any?
end

def run_parity(component, report_path, *flags)
  runner = File.expand_path(File.join(SCRIPTS, "parity_run.mjs"))
  stdout, stderr, = run_tool("node", runner, "--component", component, "--scenarios", File.expand_path(SCENARIOS),
                             "--presets", File.expand_path(ShadcnLayout::PRESETS_DIR),
                             "--servers", File.expand_path(ShadcnLayout::SERVERS_FILE), *flags, chdir: CATALOG)
  FileUtils.mkdir_p(File.dirname(report_path))
  File.write(report_path, stdout)
  report = parse_report(stdout)
  unless report.is_a?(Hash) && report.key?("pass")
    raise EnvironmentFailure, "parity_run.mjs produced no report for #{component} #{flags.join(' ')}: #{stderr.lines.last(3).join.strip}"
  end

  { "pass" => report["pass"] == true, "diffs" => Array(report["diffs"]).size, "report" => report_path }
end

def run_gates(component, options)
  directory = File.join(options[:out], component)
  selected, skipped = split_by_prefix(all_scenario_ids(component), options[:only])
  only = options[:only]
  gates = {
    "g2" =>
      if selected.empty? then { "skipped" => "no scenario id starts with --only #{only.join(',')}" }
      else run_parity(component, File.join(directory, "g2.json"), *(only.any? ? [ "--only", selected.join(",") ] : []))
      end
  }

  if options[:dx]
    ids = scenario_ids(component, DX_PREFIXES, 25) & selected
    gates["g2b"] =
      if !helpers?(component) then { "skipped" => "component has no yielded-root helpers" }
      elsif ids.empty? then { "skipped" => "no default/variant-/example__ scenarios#{only_reason(only)}" }
      else run_parity(component, File.join(directory, "g2b.json"), "--dx", "helpers", "--only", ids.join(","))
      end
  end

  if options[:themes].any?
    ids = scenario_ids(component, THEME_PREFIXES, 12) & selected
    if ids.empty?
      gates["g4"] = { "skipped" => "no variant-/default scenarios#{only_reason(only)}" }
    else
      options[:themes].each do |theme|
        gates["g4-#{theme}"] = run_parity(component, File.join(directory, "g4-#{theme}.json"), "--theme", theme, "--only", ids.join(","))
      end
      gates["g4-dark"] = run_parity(component, File.join(directory, "g4-dark.json"), "--dark", "--only", ids.join(","))
    end
  end

  result = { "pass" => gates.values.all? { |gate| gate["skipped"] || gate["pass"] }, "gates" => gates }
  result["skipped_scenarios"] = skipped_note(skipped, only) if skipped.any?
  result
end

def start_servers # rubocop:disable Naming/PredicateMethod -- starts servers, returns whether this run started them
  _, status = Open3.capture2e("ruby", File.join(SCRIPTS, "playwright_ensure.rb"))
  raise EnvironmentFailure, "no usable Playwright browser (run playwright_ensure.rb)" unless status.success?

  stdout, status = Open3.capture2("ruby", File.join(SCRIPTS, "servers.rb"), "start")
  unless status.success?
    # servers.rb reuses only healthy servers and then exits 0, so a failed start is always this run's: stop the half that came up.
    stop_servers
    raise EnvironmentFailure, "dev servers did not start (see #{ShadcnLayout::TMP_DIR}/{rails,vite}.log)"
  end

  report = parse_report(stdout)
  !(report.is_a?(Hash) && report["reused"]) # unparseable after a successful start: assume ours, so it is stopped
end

def stop_servers
  system("ruby", File.join(SCRIPTS, "servers.rb"), "stop", out: File::NULL)
end

# --no-servers: the caller promises running servers (the recorded ones, or PARITY_REACT_URL + PARITY_PHLEX_URL); without them every
# scenario would fail as a diff, which is an environment problem rather than a parity result.
def require_running_servers
  return if ENV["PARITY_REACT_URL"] && ENV["PARITY_PHLEX_URL"]

  _, status = Open3.capture2("ruby", File.join(SCRIPTS, "servers.rb"), "status")
  raise EnvironmentFailure, "--no-servers but no dev servers are running (servers.rb start, or set PARITY_REACT_URL and PARITY_PHLEX_URL)" unless status.success?
end

if $PROGRAM_NAME == __FILE__
  Dir.chdir(ROOT)
  options = parse_options(ARGV)
  components = component_names(options)

  servers_started = false
  results = {}
  begin
    options[:servers] ? servers_started = start_servers : require_running_servers
    components.each { |component| results[component] = run_gates(component, options) }
  rescue EnvironmentFailure, SystemCallError => e
    environment_failure(e.message, servers_started: servers_started) # exits; the ensure below stops the servers once
  ensure
    stop_servers if servers_started
  end

  pass = results.values.all? { |result| result["pass"] }
  puts JSON.pretty_generate(pass: pass, servers_started: servers_started, components: results)
  exit(pass ? 0 : 1)
end
