#!/usr/bin/env ruby
# frozen_string_literal: true

# The React-versus-Phlex parity smoke CI runs on every push: a fixed subset of the scenarios of every component, compared in a
# browser by parity_batch.rb (G2 DOM/style; the subset's interaction steps are G3 behavior), inside a wall-clock budget. The full gate
# stays /shadcn-audit (or parity_batch.rb --components all); dev/decisions/ci-smokes.md records why this subset and this budget.
#
#   ruby .claude/scripts/shadcn/parity_smoke.rb                         # every component, starts and stops the dev servers
#   ruby .claude/scripts/shadcn/parity_smoke.rb --components dialog,button --budget 300
#   ruby .claude/scripts/shadcn/parity_smoke.rb --list                  # print the subset, run nothing
#
# The subset, per component scenario file (dev/port/scenarios/<name>.json, files starting with `_` are primitives and left out):
# the scenario ids starting with `default`; a component without one contributes its first scenario and the ids that extend it
# (`closed__rest` brings `closed__rest__dark`), which is the closed or resting state the file opens with.
#
# --components LIST   comma list of components (default: every component scenario file)
# --budget SECONDS    wall-clock budget for the gate runs, servers excluded (default 900); exceeding it is a failure, never a skip
# --no-servers        the dev servers already run (servers.rb status, or PARITY_REACT_URL + PARITY_PHLEX_URL)
# --out DIR           parity_batch.rb reports, DIR/<component>/g2.json (default: layout.rb TMP_DIR, tmp/shadcn-port)
# --list              print { subset } and exit
#
# Prints JSON { pass, budget_seconds, elapsed_seconds, servers_started, components: { name => { scenarios, pass, diffs, seconds, report } },
#   not_run, error } on stdout and a one-line summary per failing component on stderr.
# Exit 0 no diff, 1 a component has diffs, 2 the environment or the arguments are unusable, or the budget ran out.

require_relative "layout"
require_relative "parity_batch"
require "json"
require "open3"
require "optparse"
require "rbconfig"

# The smoke subset and the budgeted run over it.
module ParitySmoke
  DEFAULT_PREFIX = "default"
  BUDGET_SECONDS = 900
  BATCH = File.expand_path("parity_batch.rb", __dir__)

  # Raised when the wall-clock budget runs out before every component was gated.
  class BudgetExceeded < StandardError; end

  module_function

  # { component => [scenario ids] } for every component scenario file of +scenarios_dir+, in name order.
  def subset(scenarios_dir)
    Dir[File.join(scenarios_dir, "*.json")].sort_by { |file| File.basename(file, ".json") }.each_with_object({}) do |file, components|
      component = File.basename(file, ".json")
      ids = scenario_ids(file)
      next if component.start_with?("_") || ids.empty?

      prefix = ids.any? { |id| id.start_with?(DEFAULT_PREFIX) } ? DEFAULT_PREFIX : ids.first
      components[component] = ids.select { |id| id.start_with?(prefix) }
    end
  end

  def scenario_ids(file)
    JSON.parse(File.read(file)).fetch("scenarios", []).filter_map { |scenario| scenario["id"] }
  end

  # Gates each component of +components+ ({ name => ids }) with one parity_batch.rb call, stopping when +budget+ seconds have passed.
  class Run
    attr_reader :results, :not_run

    def initialize(components, budget:, out:)
      @components = components
      @budget = budget
      @out = out
      @results = {}
      @not_run = []
    end

    # The budget starts here, after the servers came up: it measures the gates, not a cold Vite or Rails boot.
    def gate_all
      deadline = monotonic_now + @budget
      @components.each_with_index do |(component, ids), index|
        remaining = deadline - monotonic_now
        raise BudgetExceeded, "time budget of #{@budget.round}s exhausted before #{component}" if remaining <= 0

        @results[component] = gate(component, ids, remaining)
      rescue BudgetExceeded
        @not_run = @components.keys.drop(index)
        raise
      end
    end

    def pass? = @not_run.empty? && @results.values.all? { |result| result["pass"] }

    private

    def gate(component, ids, timeout)
      started_at = monotonic_now
      stdout, stderr, status = batch(component, ids, timeout)
      report = parse_report(stdout)
      unless report.is_a?(Hash) && [ 0, 1 ].include?(status.exitstatus)
        raise EnvironmentFailure, "parity_batch.rb #{component}: #{report&.fetch('error', nil) || stderr.lines.last(3).join.strip}"
      end

      gates = report.dig("components", component, "gates").to_h.values
      { "scenarios" => ids, "pass" => status.success?, "diffs" => gates.sum { |gate| gate["diffs"].to_i },
        "seconds" => (monotonic_now - started_at).round(1), "report" => File.join(@out, component, "g2.json") }
    end

    def batch(component, ids, timeout)
      command = [ RbConfig.ruby, BATCH, "--components", component, "--only", ids.join(","), "--no-servers", "--out", @out ]
      Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, waiter|
        stdin.close
        readers = [ stdout, stderr ].map { |stream| Thread.new { stream.read } }
        unless waiter.join(timeout)
          terminate(waiter.pid)
          raise BudgetExceeded, "time budget of #{@budget.round}s exhausted while gating #{component}"
        end

        [ *readers.map(&:value), waiter.value ]
      end
    end

    def terminate(pid)
      Process.kill("TERM", -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

def smoke_options(argv)
  options = { components: nil, budget: ParitySmoke::BUDGET_SECONDS, servers: true, out: ShadcnLayout::TMP_DIR, list: false }
  OptionParser.new do |parser|
    parser.banner = "usage: parity_smoke.rb [--components a,b] [--budget SECONDS] [--no-servers] [--out DIR] [--list]"
    parser.on("--components LIST", "comma list of components (default: every component scenario file)") do |value|
      options[:components] = value.split(",").map(&:strip).reject(&:empty?).uniq
    end
    parser.on("--budget SECONDS", Float, "wall-clock budget of the gate runs (default #{ParitySmoke::BUDGET_SECONDS})") { |value| options[:budget] = value }
    parser.on("--no-servers", "servers already running") { options[:servers] = false }
    parser.on("--out DIR", "report directory (default #{ShadcnLayout::TMP_DIR})") { |value| options[:out] = value }
    parser.on("--list", "print the subset and exit") { options[:list] = true }
  end.parse!(argv)
  options
rescue OptionParser::ParseError => e
  environment_failure(e.message)
end

def smoke_subset(options)
  subset = ParitySmoke.subset(ShadcnLayout::SCENARIOS_DIR)
  return subset unless options[:components]

  unknown = options[:components] - subset.keys
  environment_failure("no component scenario file for: #{unknown.join(', ')}") if unknown.any?
  subset.slice(*options[:components])
end

def print_summary(run, report)
  scenarios = run.results.values.sum { |result| result["scenarios"].size }
  warn format("parity smoke: %<components>d components, %<scenarios>d scenarios, %<seconds>.0fs of %<budget>.0fs: %<verdict>s",
              components: run.results.size, scenarios: scenarios, seconds: report[:elapsed_seconds], budget: report[:budget_seconds],
              verdict: report[:pass] ? "pass" : "FAIL")
  run.results.each do |component, result|
    warn "  #{component}: #{result['diffs']} diff(s), see #{result['report']}" unless result["pass"]
  end
  warn "  not run: #{run.not_run.join(', ')}" if run.not_run.any?
  warn "  #{report[:error]}" if report[:error]
end

if $PROGRAM_NAME == __FILE__
  Dir.chdir(ROOT)
  options = smoke_options(ARGV)
  subset = smoke_subset(options)
  if options[:list]
    puts JSON.pretty_generate(subset: subset)
    exit 0
  end

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  run = ParitySmoke::Run.new(subset, budget: options[:budget], out: options[:out])
  servers_started = false
  error = nil
  begin
    options[:servers] ? servers_started = start_servers : require_running_servers
    run.gate_all
  rescue EnvironmentFailure, ParitySmoke::BudgetExceeded, SystemCallError => e
    error = e.message
  ensure
    stop_servers if servers_started
  end

  report = { pass: error.nil? && run.pass?, budget_seconds: options[:budget],
             elapsed_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(1),
             servers_started: servers_started, components: run.results }
  report[:not_run] = run.not_run if run.not_run.any?
  report[:error] = error if error
  puts JSON.pretty_generate(report)
  print_summary(run, report)
  exit 2 if error
  exit(report[:pass] ? 0 : 1)
end
