# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "date" # phlex 2.4.1 references Date without requiring it; plain Ruby 4 does not preload it
require "json"
require "open3"
require "chadcn"
require_relative "scenarios"

module Bench
  # Measures the scenarios and compares allocations with the recorded baseline.
  module Runner
    BASELINE = File.expand_path("baseline.json", __dir__)
    FLAGS = %w[--json --check --record --help].freeze
    VALUE_FLAGS = %w[--expect-improvement --against].freeze
    ITERATIONS = 200
    WARMUP = 20
    # Allocations may exceed the baseline by this fraction before --check fails (counts are deterministic, so for tiny counts one
    # extra allocation already fails).
    DEFAULT_TOLERANCE = 0.02
    USAGE = "usage: bin/bench [--json] [--check [--expect-improvement SCENARIO=PERCENT[,...] [--against FILE_OR_GIT_REV]]] | bin/bench --record"
    HELP = <<~TEXT
      #{USAGE}

        (no flag)                       print the table
        --json                          print the numbers as JSON
        --check                         exit 1 when a scenario exceeds baseline + tolerance (skipped on another Ruby or Phlex)
        --record                        rewrite dev/bench/baseline.json with today's allocations
        --expect-improvement S=P[,...]  with --check: exit 1 unless each named scenario S allocates at least P percent less
                                        than the baseline (P is 0 to 100; button=25,card=20). Allocations only, never time.
                                        It replaces the tolerance gate (unnamed scenarios are not checked) and, unlike
                                        --check, never skips: a baseline from another Ruby or Phlex, a missing baseline
                                        or an unknown scenario fails (before anything is measured). The flag may be repeated: the
                                        lists are merged, and a scenario named twice exits 2.
        --against FILE_OR_GIT_REV       baseline for --expect-improvement: a baseline JSON file, or a git revision whose
                                        dev/bench/baseline.json is read (default: the current dev/bench/baseline.json); once only
    TEXT

    module_function

    def call(argv)
      options = parse(argv)
      if options.is_a?(String)
        warn "invalid option(s): #{options}; #{USAGE}"
        return 2
      end

      if options[:help]
        puts HELP
        return 0
      end

      # Everything that can fail without a measurement fails first: measuring takes seconds.
      if options[:expectations]
        baseline = prepare_improvement(expectations: options[:expectations], source: options[:against] || BASELINE)
        return abort_with(baseline) if baseline.is_a?(String)

        return improvement(results: measure, expectations: options[:expectations], baseline:, json: options[:json])
      end

      baseline = default_baseline
      return abort_with(baseline) if baseline.is_a?(String) && !options[:record]
      if options[:record]
        warn "#{baseline}; rewriting it (tolerance reset to #{DEFAULT_TOLERANCE})" if baseline.is_a?(String)
        return record(results: measure, baseline: baseline.is_a?(Hash) ? baseline : {})
      end
      return check(results: measure, baseline:, json: options[:json]) if options[:check]

      report(results: measure, baseline:, json: options[:json])
    end

    # @return [Integer] exit status 1 after printing the message
    def abort_with(message)
      warn message
      1
    end

    # @return [Hash, String] the validated default baseline ({} when the file does not exist), or a message when it is invalid
    def default_baseline
      File.file?(BASELINE) ? load_baseline(BASELINE) : {}
    end

    # @return [Hash, String] the options, or a message when the arguments are invalid
    def parse(argv)
      options = {}
      arguments = argv.dup
      until arguments.empty?
        flag = arguments.shift
        if VALUE_FLAGS.include?(flag)
          value = arguments.shift
          return "#{flag} needs a value" if value.nil? || value.start_with?("--")

          error = assign_value_flag(options, flag, value)
          return error if error
        elsif FLAGS.include?(flag)
          options[flag.delete_prefix("--").to_sym] = true
        else
          return flag
        end
      end
      inconsistency(options)
    end

    # Stores a value flag in the options. --expect-improvement may be repeated (the lists are merged, a scenario named twice is
    # rejected); --against may not.
    # @return [String, nil] a message when the value is invalid or the flag conflicts with an earlier one
    def assign_value_flag(options, flag, value)
      if flag == "--against"
        return "--against given more than once" if options.key?(:against)

        options[:against] = value
        return
      end

      expectations = parse_expectations(value)
      return "#{value.inspect} is not SCENARIO=PERCENT[,...] with PERCENT from 0 to 100" unless expectations

      repeated = (options[:expectations] || {}).keys & expectations.keys
      return "--expect-improvement names #{repeated.join(", ")} more than once" unless repeated.empty?

      options[:expectations] = (options[:expectations] || {}).merge(expectations)
      nil
    end

    # @return [Hash{String => Float}, nil] scenario => minimum percent drop, nil when the text is malformed
    def parse_expectations(text)
      pairs = text.split(",", -1).map { |pair| pair.split("=", -1) }
      return unless pairs.any? && pairs.all? { |pair| pair.size == 2 && pair[0].match?(/\A\w+\z/) && pair[1].match?(/\A\d+(\.\d+)?\z/) }

      expectations = pairs.to_h { |name, percent| [ name, Float(percent) ] }
      expectations if pairs.size == expectations.size && expectations.values.all? { |percent| percent <= 100 }
    end

    # @return [Hash, String] the options, or a message when the flags cannot be combined
    def inconsistency(options)
      if options[:record] && options.keys.intersect?(%i[check json expectations])
        return "--record cannot be combined with --check, --json or --expect-improvement"
      end
      return "--expect-improvement needs --check" if options[:expectations] && !options[:check]
      return "--against needs --expect-improvement" if options[:against] && !options[:expectations]

      options
    end

    # @return [Hash{String => Hash}] scenario => {"us" => Float, "allocations" => Integer} per render
    def measure
      Scenarios::ALL.transform_values do |build|
        WARMUP.times { build.call.call }
        GC.start
        GC.disable
        begin
          allocations_before = GC.stat(:total_allocated_objects)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ITERATIONS.times { build.call.call }
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          allocations_during = GC.stat(:total_allocated_objects) - allocations_before
        ensure
          GC.enable
        end
        { "us" => (elapsed * 1_000_000 / ITERATIONS).round(1), "allocations" => (allocations_during.to_f / ITERATIONS).round }
      end
    end

    # @return [Hash{String => String}] the versions allocation counts depend on
    def environment = { "ruby" => RUBY_VERSION, "phlex" => Phlex::VERSION }

    def record(results:, baseline:)
      recorded_baseline = { "tolerance" => baseline.fetch("tolerance", DEFAULT_TOLERANCE), **environment,
                            "allocations" => results.transform_values { |measurement| measurement["allocations"] } }
      File.write(BASELINE, "#{JSON.pretty_generate(recorded_baseline)}\n")
      puts "recorded #{BASELINE}"
      0
    end

    def report(results:, baseline:, json:)
      if json
        puts JSON.pretty_generate(results)
        return 0
      end

      recorded = baseline.fetch("allocations", {})
      reference_allocations = results.dig("reference", "allocations").to_f
      puts format("%-12s %12s %14s %10s %12s", "scenario", "us/render", "allocs/render", "x ref", "baseline")
      results.each do |name, measurement|
        ratio = reference_allocations.zero? ? "-" : format("%.1f", measurement["allocations"] / reference_allocations)
        puts format("%-12s %12.1f %14d %10s %12s", name, measurement["us"], measurement["allocations"], ratio, recorded.fetch(name, "-"))
      end
      0
    end

    # @return [Array<String>] one message per scenario over baseline + tolerance, or without a baseline
    def regressions(results:, baseline:)
      recorded = baseline.fetch("allocations", {})
      tolerance = baseline.fetch("tolerance", DEFAULT_TOLERANCE)
      results.filter_map do |name, measurement|
        limit = recorded[name]
        next "#{name}: no baseline (run bin/bench --record)" unless limit
        next if measurement["allocations"] <= limit * (1 + tolerance)

        "#{name}: #{measurement["allocations"]} allocations per render, baseline #{limit} (+#{(tolerance * 100).round(1)}% allowed)"
      end
    end

    # @return [Hash{String => String}] key => version recorded in the baseline, for each version differing from the running one
    #   (a baseline without a version stamp counts as drift)
    def environment_drift(baseline)
      environment.filter_map { |key, version| [ key, baseline[key] || "unknown" ] unless baseline[key] == version }.to_h
    end

    # @return [String] which Ruby or Phlex the baseline was recorded on, and which one is running
    def drift_message(drift)
      "baseline recorded on #{drift.map { |key, version| "#{key} #{version}" }.join(", ")}; running " \
        "#{drift.keys.map { |key| "#{key} #{environment[key]}" }.join(", ")}"
    end

    def check(results:, baseline:, json:)
      drift = environment_drift(baseline)
      unless drift.empty?
        warn "#{drift_message(drift)}: allocation gate skipped (run bin/bench --record)"
        report(results:, baseline:, json:)
        return 0
      end

      failures = regressions(results:, baseline:)
      report(results:, baseline:, json:)
      warn failures.join("\n") unless failures.empty?
      failures.empty? ? 0 : 1
    end

    # @param source [String] a baseline JSON file, or a git revision whose dev/bench/baseline.json is read
    # @param repo [String] the directory git runs in to read a revision
    # @return [Hash, String] the parsed baseline, or a message when it cannot be read
    def load_baseline(source, repo: File.expand_path("../..", __dir__))
      content =
        if File.file?(source)
          File.read(source)
        else
          output, status = Open3.capture2e("git", "show", "--end-of-options", "#{source}:./dev/bench/baseline.json",
                                           chdir: repo)
          return "cannot read a baseline from #{source.inspect}: not a file and not a git revision with dev/bench/baseline.json" unless status.success?

          output
        end
      problem = baseline_problem(baseline = JSON.parse(content))
      problem ? "cannot read a baseline from #{source.inspect}: #{problem}" : baseline
    rescue JSON::ParserError, SystemCallError => error
      "cannot read a baseline from #{source.inspect}: #{error.message}"
    end

    # A missing Ruby or Phlex stamp is not a problem here: it counts as drift, see environment_drift.
    # @return [String, nil] what is wrong with a parsed baseline, nil when it is usable
    def baseline_problem(baseline)
      return "not a JSON object" unless baseline.is_a?(Hash)

      allocations = baseline.fetch("allocations", {})
      return "allocations must map scenarios to integers" unless allocations.is_a?(Hash) && allocations.values.all?(Integer)

      tolerance = baseline.fetch("tolerance", DEFAULT_TOLERANCE)
      return "tolerance must be a number from 0 up" unless tolerance.is_a?(Numeric) && !tolerance.negative?

      "#{environment.keys.join(" and ")} must be version strings" unless environment.keys.all? { |key| baseline.fetch(key, "").is_a?(String) }
    end

    Improvement = Struct.new(:name, :before, :now, :drop, :wanted, :verdict, keyword_init: true)

    # @return [Array<Improvement>] one per expected scenario: baseline and current allocations, drop and wanted percent, verdict
    def improvements(results:, baseline:, expectations:)
      recorded = baseline.fetch("allocations", {})
      expectations.map do |name, wanted|
        before = recorded[name]
        now = results.dig(name, "allocations")
        drop = (before - now) * 100.0 / before if before&.positive? && now
        Improvement.new(name:, before:, now:, drop:, wanted:, verdict: improvement_verdict(before:, now:, drop:, wanted:))
      end
    end

    def improvement_verdict(before:, now:, drop:, wanted:)
      return "unknown scenario" unless now
      return "no baseline" unless before
      return "empty baseline" unless drop

      drop >= wanted ? "ok" : "too small"
    end

    # Runs before anything is measured.
    # @return [Hash, String] the baseline to compare with, or the message why the expectation cannot be verified
    def prepare_improvement(expectations:, source:)
      baseline = load_baseline(source)
      return baseline if baseline.is_a?(String)

      drift = environment_drift(baseline)
      unless drift.empty?
        return "#{drift_message(drift)}: allocation counts are not comparable, improvement not verified " \
               "(record the baseline on this Ruby and Phlex, or pass --against)"
      end

      unknown = expectations.keys - Scenarios::ALL.keys
      return "unknown scenario(s) #{unknown.join(", ")}; known: #{Scenarios::ALL.keys.join(", ")}" unless unknown.empty?

      baseline
    end

    # Compares the current allocations with an earlier (already validated) baseline and exits 1 unless every named scenario
    # dropped enough. Never skips.
    # @return [Integer] exit status
    def improvement(results:, expectations:, baseline:, json:)
      rows = improvements(results:, baseline:, expectations:)
      json ? print_improvement_json(results:, rows:) : print_improvement_table(results:, baseline:, rows:)
      rows.all? { |row| row.verdict == "ok" } ? 0 : 1
    end

    def print_improvement_json(results:, rows:)
      improvement = rows.to_h do |row|
        [ row.name, { "before" => row.before, "now" => row.now, "drop" => row.drop&.round(2), "wanted" => row.wanted, "verdict" => row.verdict } ]
      end
      puts JSON.pretty_generate({ "results" => results, "improvement" => improvement })
    end

    def print_improvement_table(results:, baseline:, rows:)
      report(results:, baseline:, json: false)
      puts format("%-12s %10s %10s %8s %8s  %s", "scenario", "before", "now", "drop %", "wanted %", "verdict")
      rows.each do |row|
        puts format("%-12s %10s %10s %8s %8.1f  %s", row.name, row.before || "-", row.now || "-", row.drop ? format("%.1f", row.drop) : "-",
                    row.wanted, row.verdict)
      end
    end
  end
end
