#!/usr/bin/env ruby
# frozen_string_literal: true

# Resumable run state for /shadcn-run. The orchestrator asks this script what to do next
# instead of reasoning about waves itself.
#
#   ruby .claude/scripts/shadcn/port_state.rb init [--only a,b] [--pilot a,b,c] [--skip-tier third_party[,client]|none]
#   ruby .claude/scripts/shadcn/port_state.rb next [--concurrency 4]     # JSON batch for the lowest unfinished wave
#   ruby .claude/scripts/shadcn/port_state.rb set NAME STATUS [--note TXT] [--iteration N] [--sha SHA]
#   ruby .claude/scripts/shadcn/port_state.rb bump N                      # count N builder/planner dispatches (global cap)
#   ruby .claude/scripts/shadcn/port_state.rb checkpoint                  # JSON { stop, reason, details }: infra_blocked | dispatch_cap | pilot_blocked | wave_blocked_ratio
#   ruby .claude/scripts/shadcn/port_state.rb retry-blocked [NAME...]     # acknowledge a stop: blocked -> pending, dispatch counter -> 0
#   ruby .claude/scripts/shadcn/port_state.rb summary [--json]
#   ruby .claude/scripts/shadcn/port_state.rb reset NAME|all
#   ruby .claude/scripts/shadcn/port_state.rb --check                     # every path the infra entries own exists (run from the repo root); exit 1 lists the stale ones
#
# Statuses: pending -> planned -> done | blocked.  `built` = built but not browser-verified (--no-browser): never returned by `next`
# again, and it satisfies dependents.
# `next` only returns components whose dependencies are done/built; dependents of a blocked component never run and are
# reported under `waiting` with the root blocker. Stop rules live in `checkpoint`, not in the command prose.
# Waves: 0 infra (theme, harness, primitives), 1 pilot (one per behavior family), 2.. fan-out by oracle dependency layers.

require_relative "layout"
require "json"
require "optparse"
require "time"
require "fileutils"

STATE = ShadcnLayout::STATE_FILE
GRAPH = "#{ShadcnLayout::ORACLE_DIR}/graph.json"
STATUSES = %w[pending planned built done blocked].freeze
DEFAULT_PILOT = %w[button switch dialog tooltip dropdown-menu select].freeze
INFRA = [
  { "name" => "_theme", "owns" => ["#{ShadcnLayout::THEME_DIR}/** (bug fixes only)", "#{ShadcnLayout::CONTROLLER_DIR}/theme_controller.js", "#{ShadcnLayout::CATALOG_DIR}/src/index.css", "#{ShadcnLayout::RUBY_DIR}/theme.rb", "#{ShadcnLayout::GEM_DIR}/lib/tasks/chadcn*.rake", "#{ShadcnLayout::RUBY_TEST_DIR}/theme_test.rb"] },
  { "name" => "_harness", "owns" => ["#{ShadcnLayout::DEV_DIR}/parity/**", "#{ShadcnLayout::DUMMY_DIR}/**", "#{ShadcnLayout::CATALOG_DIR}/src/parity/**", "#{ShadcnLayout::CATALOG_DIR}/vite.config.ts", "#{ShadcnLayout::CATALOG_DIR}/package.json"] },
  { "name" => "_primitives", "owns" => ["#{ShadcnLayout::PRIMITIVES_DIR}/**", "config/importmap.rb (primitives and controllers pins)", "#{ShadcnLayout::CATALOG_DIR}/src/parity/primitives/**", "#{ShadcnLayout::SCENARIOS_DIR}/_primitives-*.json"] },
  { "name" => "_base", "owns" => ["#{ShadcnLayout::RUBY_DIR}/base.rb", "#{ShadcnLayout::RUBY_TEST_DIR}/base_test.rb"] },
  { "name" => "_icons", "owns" => ["#{ShadcnLayout::RUBY_DIR}/icon.rb", "#{ShadcnLayout::RUBY_DIR}/icons/**"] },
].freeze

INFRA_DEPS = { "_harness" => %w[_theme _base _icons], "_primitives" => %w[_harness] }.freeze
RUNNABLE = %w[pending planned].freeze
SATISFIED = %w[done built].freeze
DISPATCH_CAP_FACTOR = 3
RATIO_MIN_WAVE = 4 # waves smaller than this are too small for a percentage to mean anything

def load_state = JSON.parse(File.read(STATE))
def save_state(s) = File.write(STATE, JSON.pretty_generate(s))

def component_entry(name, tier, wave)
  { "status" => "pending", "tier" => tier, "wave" => wave, "iteration" => 0, "note" => nil, "last_green_sha" => nil, "updated_at" => Time.now.utc.iso8601 }
end

def init(opts)
  graph = JSON.parse(File.read(GRAPH))
  names = graph["waves"].flat_map { |w| w["components"] }
  names &= opts[:only] if opts[:only]

  # --skip-tier removes whole tiers from the plan (e.g. the 11 components that wrap React-only libraries). The choice is
  # stored in state.json, so a later `init` (and /shadcn-run) reuses it; `--skip-tier none` clears it.
  skip_tiers = opts.key?(:skip_tiers) ? opts[:skip_tiers] : (File.exist?(STATE) ? load_state.fetch("skip_tiers", []) : [])
  skip_tiers = [] if skip_tiers == ["none"]
  unknown = skip_tiers - graph["tiers"].values.uniq
  abort("unknown tier #{unknown.join(', ')} (known: #{graph['tiers'].values.uniq.sort.join(', ')})") if unknown.any?
  skipped = names.select { |n| skip_tiers.include?(graph["tiers"][n].to_s) }
  broken = (names - skipped).filter_map { |n| (needs = (graph["nodes"][n] || []) & skipped).any? ? "#{n} needs #{needs.join(', ')}" : nil }
  abort("--skip-tier #{skip_tiers.join(',')} would leave components that depend on skipped ones: #{broken.join('; ')}") if broken.any?
  names -= skipped
  pilot = (opts[:pilot] || DEFAULT_PILOT) & names
  layers = graph["waves"].to_h { |w| [w["wave"], w["components"] & names] }

  components = {}
  INFRA.each { |i| components[i["name"]] = component_entry(i["name"], "infra", 0).merge("owns" => i["owns"], "kind" => "infra") }
  pilot.each { |n| components[n] = component_entry(n, graph["tiers"][n], 1).merge("kind" => "pilot") }
  fix_dependency_waves!(components, graph["nodes"]) # pilots may need mini-waves (button before dialog)
  base = components.values.select { |c| c["kind"] == "pilot" }.map { |c| c["wave"] }.max || 0
  layers.each do |layer, list|
    (list - pilot).each { |n| components[n] = component_entry(n, graph["tiers"][n], base + layer).merge("kind" => "fanout") }
  end
  fix_dependency_waves!(components, graph["nodes"]) # dependencies always win

  components.each { |n, c| c["deps"] = c["kind"] == "infra" ? INFRA_DEPS.fetch(n, []) : ((graph["nodes"][n] || []) & components.keys) }

  # Idempotent: keep progress for components whose oracle source did not change; reset the ones that did.
  attach_source_shas!(components)
  reset = []
  kept = 0
  if File.exist?(STATE)
    old = load_state["components"]
    components.each do |name, c|
      prev = old[name]
      next unless prev

      if prev["source_sha"] == c["source_sha"]
        c.merge!(prev.slice("status", "iteration", "note", "last_green_sha", "updated_at"))
        kept += 1
      elsif prev["status"] != "pending"
        reset << name
      end
    end
  end

  FileUtils.mkdir_p(File.dirname(STATE))
  dispatches = File.exist?(STATE) ? load_state.fetch("dispatches", 0) : 0
  save_state("created_at" => Time.now.utc.iso8601, "skip_tiers" => skip_tiers, "skipped" => skipped.sort, "oracle" => JSON.parse(File.read(File.join(File.dirname(GRAPH), "VERSION.json"))), "dispatches" => dispatches, "components" => components)
  warn "skipped (tier #{skip_tiers.join(',')}): #{skipped.size} components, kept out of the plan" if skipped.any?
  warn "state: #{components.size} items, #{components.values.map { |c| c['wave'] }.max + 1} waves, #{kept} preserved"
  warn "reset to pending (oracle source changed): #{reset.join(', ')}" if reset.any?
end

def attach_source_shas!(components)
  components.each do |name, c|
    manifest = File.join(File.dirname(GRAPH), "manifest", "#{name}.json")
    c["source_sha"] = File.exist?(manifest) ? JSON.parse(File.read(manifest))["source_sha"] : "infra"
  end
end

# Guarantee wave(component) > wave(each dependency present in the run).
def fix_dependency_waves!(components, nodes)
  changed = true
  while changed
    changed = false
    components.each do |name, c|
      next if c["tier"] == "infra"

      (nodes[name] || []).each do |dep|
        next unless components[dep]
        next if components[dep]["wave"] < c["wave"]

        c["wave"] = components[dep]["wave"] + 1
        changed = true
      end
    end
  end
end

# Root blocker of a component: a dependency that is blocked, or (transitively) waits on a blocked one. nil if none.
def root_blocker(components, name, seen = [])
  return nil if seen.include?(name)

  (components[name]["deps"] || []).each do |dep|
    next unless components[dep]
    return dep if components[dep]["status"] == "blocked"

    found = root_blocker(components, dep, seen + [name])
    return found if found
  end
  nil
end

def deps_satisfied?(components, name)
  (components[name]["deps"] || []).all? { |d| components[d].nil? || SATISFIED.include?(components[d]["status"]) }
end

def next_batch(state, concurrency)
  comps = state["components"]
  waiting = {}
  comps.each do |name, c|
    next unless RUNNABLE.include?(c["status"])

    blocker = root_blocker(comps, name)
    waiting[name] = "dep blocked: #{blocker}" if blocker
  end

  comps.values.map { |c| c["wave"] }.uniq.sort.each do |wave|
    runnable = comps.select { |n, c| c["wave"] == wave && RUNNABLE.include?(c["status"]) && !waiting.key?(n) && deps_satisfied?(comps, n) }
    next if runnable.empty?

    batch = runnable.keys.first(concurrency)
    return {
      "wave" => wave,
      "kind" => runnable.values.first["kind"],
      "batch" => batch.map { |n| { "name" => n, "status" => comps[n]["status"], "iteration" => comps[n]["iteration"], "owns" => comps[n]["owns"] }.compact },
      "remaining_runnable" => runnable.size - batch.size,
      "waiting" => waiting,
      "done" => false,
    }
  end
  { "wave" => nil, "batch" => [], "waiting" => waiting, "done" => true }
end

# Deterministic stop rules for the orchestrator. Call after every batch.
def checkpoint(state)
  comps = state["components"]
  blocked = ->(sel) { comps.select { |_, c| sel.call(c) && c["status"] == "blocked" }.keys }

  infra = blocked.call(->(c) { c["kind"] == "infra" })
  return { "stop" => true, "reason" => "infra_blocked", "details" => infra } if infra.any?

  cap = DISPATCH_CAP_FACTOR * comps.size
  dispatches = state.fetch("dispatches", 0)
  return { "stop" => true, "reason" => "dispatch_cap", "details" => ["#{dispatches} dispatches > cap #{cap}"] } if dispatches > cap

  pilots = blocked.call(->(c) { c["kind"] == "pilot" })
  return { "stop" => true, "reason" => "pilot_blocked", "details" => pilots } if pilots.any?

  comps.select { |_, c| c["kind"] == "fanout" }.group_by { |_, c| c["wave"] }.each do |wave, list|
    next if list.size < RATIO_MIN_WAVE

    bad = list.select { |_, c| c["status"] == "blocked" }.map(&:first)
    return { "stop" => true, "reason" => "wave_blocked_ratio", "details" => ["wave #{wave}: #{bad.size}/#{list.size} blocked: #{bad.join(', ')}"] } if bad.size * 4 > list.size
  end
  { "stop" => false, "reason" => nil, "details" => [] }
end

def summary(state, json)
  rows = state["components"].map { |n, c| [c["wave"], n, c["status"], c["iteration"], c["note"]] }.sort_by { |r| [r[0], r[1]] }
  return puts(JSON.pretty_generate(rows.map { |w, n, s, i, note| { wave: w, name: n, status: s, iteration: i, note: note } })) if json

  tally = state["components"].values.map { |c| c["status"] }.tally
  puts "wave  component             status    iter  note"
  rows.each { |w, n, s, i, note| puts format("%-5s %-21s %-9s %-5s %s", w, n, s, i, note.to_s[0, 70]) }
  puts "\n#{tally.map { |k, v| "#{k}=#{v}" }.join('  ')}"
  puts "skipped by --skip-tier #{state['skip_tiers'].join(',')}: #{state['skipped'].join(', ')}" if state["skipped"].to_a.any?
end

# `--check`: every path the infra entries own exists (a trailing "(note)" is ignored); exits 1 and lists the stale ones, so a removed or
# moved file is noticed here instead of misleading the next /shadcn-run.
def check_infra_owns
  stale = INFRA.flat_map { |entry| entry["owns"].map { |owns| [entry["name"], owns.sub(/\s+\(.*\)\z/, "")] } }
               .reject { |_, pattern| Dir.glob(pattern).any? }
  stale.each { |name, pattern| warn "#{name}: #{pattern} matches nothing" }
  puts(stale.empty? ? "infra owns ok (#{INFRA.size} entries)" : "#{stale.size} stale infra owns")
  exit(stale.empty? ? 0 : 1)
end

cmd = ARGV.shift
opts = {}
parser = OptionParser.new do |o|
  o.on("--only LIST") { |v| opts[:only] = v.split(",") }
  o.on("--pilot LIST") { |v| opts[:pilot] = v.split(",") }
  o.on("--skip-tier LIST") { |v| opts[:skip_tiers] = v.split(",") }
  o.on("--concurrency N", Integer) { |v| opts[:concurrency] = v }
  o.on("--note TXT") { |v| opts[:note] = v }
  o.on("--iteration N", Integer) { |v| opts[:iteration] = v }
  o.on("--sha SHA") { |v| opts[:sha] = v }
  o.on("--json") { opts[:json] = true }
end
parser.parse!

case cmd
when "--check", "check" then check_infra_owns
when "init" then init(opts)
when "next" then puts JSON.pretty_generate(next_batch(load_state, opts[:concurrency] || 4))
when "checkpoint" then puts JSON.pretty_generate(checkpoint(load_state))
when "bump"
  state = load_state
  state["dispatches"] = state.fetch("dispatches", 0) + Integer(ARGV.first || 1)
  save_state(state)
when "retry-blocked"
  state = load_state
  targets = ARGV.empty? ? state["components"].select { |_, c| c["status"] == "blocked" }.keys : ARGV
  targets.each { |n| state["components"][n]&.merge!("status" => "pending", "iteration" => 0, "note" => nil) }
  state["dispatches"] = 0
  save_state(state)
  warn "retrying: #{targets.join(', ')}"
when "set"
  name, status = ARGV
  abort("status must be one of #{STATUSES.join(', ')}") unless STATUSES.include?(status)
  state = load_state
  abort("unknown component #{name}") unless state["components"][name]
  c = state["components"][name]
  c["status"] = status
  c["note"] = opts[:note] if opts.key?(:note)
  c["iteration"] = opts[:iteration] if opts[:iteration]
  c["last_green_sha"] = opts[:sha] if opts[:sha]
  c["updated_at"] = Time.now.utc.iso8601
  save_state(state)
when "summary" then summary(load_state, opts[:json])
when "reset"
  state = load_state
  targets = ARGV.first == "all" ? state["components"].keys : ARGV
  targets.each { |n| state["components"][n]&.merge!("status" => "pending", "iteration" => 0, "note" => nil) }
  save_state(state)
else
  abort("usage: --check | init | next | checkpoint | bump N | retry-blocked [NAME...] | set NAME STATUS | summary | reset NAME|all")
end
