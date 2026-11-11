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
# Prints JSON { pass, budget_seconds, elapsed_seconds, gate_seconds, servers_started, components: { name => { scenarios, pass, diffs, seconds,
#   report } }, not_run, error } on stdout and a one-line summary per failing component on stderr. elapsed_seconds covers the whole run,
#   gate_seconds only the gates (what the budget measures); not_run lists the components without a verdict, including the one whose gate
#   failed or ran over the budget.
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
  TERM_GRACE_SECONDS = 10
  BATCH = File.expand_path("parity_batch.rb", __dir__)

  # Raised when the wall-clock budget runs out before every component was gated.
  class BudgetExceeded < StandardError; end

  # What one component's gate run concluded: the scenario ids it ran, the verdict, the diff count, its duration and the g2 report path.
  Verdict = Data.define(:scenarios, :pass, :diffs, :seconds, :report) do
    alias_method :pass?, :pass
  end

  module_function

  # { component => [scenario ids] } for every component scenario file of +scenarios_dir+, in name order.
  def subset(scenarios_dir)
    scenario_files = Dir[File.join(scenarios_dir, "*.json")].sort_by { |scenario_file| File.basename(scenario_file, ".json") }
    scenario_files.each_with_object({}) do |scenario_file, components|
      component = File.basename(scenario_file, ".json")
      next if component.start_with?("_")

      ids = scenario_ids(scenario_file)
      next if ids.empty?

      prefix = ids.any? { |id| id.start_with?(DEFAULT_PREFIX) } ? DEFAULT_PREFIX : ids.first
      components[component] = ids.select { |id| id.start_with?(prefix) }
    end
  end

  def scenario_ids(file)
    JSON.parse(File.read(file)).fetch("scenarios", []).filter_map { |scenario| scenario["id"] }
  end
  private_class_method :scenario_ids

  # Gates each component of +components+ ({ name => ids }) with one parity_batch.rb call, stopping when +budget+ seconds have passed.
  class Run
    attr_reader :verdicts, :not_run

    def initialize(components, budget:, out:)
      @components = components
      @budget = budget
      @out = out
      @verdicts = {}
      @not_run = []
    end

    # The budget starts here, after the servers came up: it measures the gates, not a cold Vite or Rails boot.
    def gate_all
      deadline = monotonic_now + @budget
      @components.each_with_index do |(component, ids), index|
        remaining = deadline - monotonic_now
        raise BudgetExceeded, "time budget of #{@budget.round}s exhausted before #{component}" if remaining <= 0

        @verdicts[component] = component_verdict(component, ids, remaining)
      rescue BudgetExceeded, EnvironmentFailure
        @not_run = @components.keys.drop(index)
        raise
      end
    end

    def pass? = @not_run.empty? && @verdicts.values.all?(&:pass?)

    private

    def component_verdict(component, ids, timeout)
      started_at = monotonic_now
      stdout, stderr, status = parity_batch_output(component, ids, timeout)
      report = parse_report(stdout)
      report = nil unless report.is_a?(Hash)
      component_report = report&.dig("components", component)
      unless component_report.is_a?(Hash) && [ 0, 1 ].include?(status.exitstatus) && component_report["pass"] == status.success?
        raise EnvironmentFailure, "parity_batch.rb #{component} (exit #{status.exitstatus}): " \
                                  "#{report&.fetch('error', nil) || stderr.lines.last(3).join.strip}"
      end

      gate_reports = component_report["gates"].to_h.values
      Verdict.new(scenarios: ids, pass: status.success?, diffs: gate_reports.sum { |gate_report| gate_report["diffs"].to_i },
                  seconds: (monotonic_now - started_at).round(1), report: component_report.dig("gates", "g2", "report"))
    end

    def parity_batch_output(component, ids, timeout)
      command = [ RbConfig.ruby, BATCH, "--components", component, "--only", ids.join(","), "--no-servers", "--out", @out ]
      Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, waiter|
        stdin.close
        readers = [ stdout, stderr ].map { |stream| Thread.new { stream.read } }
        unless waiter.join(timeout)
          terminate(waiter)
          raise BudgetExceeded, "time budget of #{@budget.round}s exhausted while gating #{component}"
        end

        [ *readers.map(&:value), waiter.value ]
      end
    end

    # TERM to the whole process group (parity_batch.rb, its node and the browser), KILL when it is still there after the grace period.
    def terminate(waiter)
      Process.kill("TERM", -waiter.pid)
      return if waiter.join(TERM_GRACE_SECONDS)

      Process.kill("KILL", -waiter.pid)
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
      raise OptionParser::InvalidArgument, "--components needs at least one component name" if options[:components].empty?
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
  environment_failure("no component scenario file in #{ShadcnLayout::SCENARIOS_DIR}") if subset.empty?
  return subset unless options[:components]

  unknown = options[:components] - subset.keys
  environment_failure("no component scenario file for: #{unknown.join(', ')}") if unknown.any?
  subset.slice(*options[:components])
end

def print_summary(run, report)
  scenario_count = run.verdicts.values.sum { |verdict| verdict.scenarios.size }
  warn format("parity smoke: %<components>d components, %<scenarios>d scenarios, %<seconds>.0fs of %<budget>.0fs: %<verdict>s",
              components: run.verdicts.size, scenarios: scenario_count, seconds: report[:gate_seconds], budget: report[:budget_seconds],
              verdict: report[:pass] ? "pass" : "FAIL")
  run.verdicts.each do |component, verdict|
    warn "  #{component}: #{verdict.diffs} diff(s), see #{verdict.report}" unless verdict.pass?
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
  gate_started_at = nil
  error = nil
  begin
    options[:servers] ? servers_started = start_servers : require_running_servers
    gate_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    run.gate_all
  rescue EnvironmentFailure, ParitySmoke::BudgetExceeded, SystemCallError => e
    error = e.message
  ensure
    stop_servers if servers_started
  end

  report = { pass: error.nil? && run.pass?, budget_seconds: options[:budget],
             elapsed_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(1),
             gate_seconds: gate_started_at ? (Process.clock_gettime(Process::CLOCK_MONOTONIC) - gate_started_at).round(1) : 0.0,
             servers_started: servers_started, components: run.verdicts.transform_values(&:to_h) }
  report[:not_run] = run.not_run if run.not_run.any?
  report[:error] = error if error
  puts JSON.pretty_generate(report)
  print_summary(run, report)
  exit 2 if error
  exit(report[:pass] ? 0 : 1)
end
