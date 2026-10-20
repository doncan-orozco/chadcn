# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "date" # phlex 2.4.1 references Date without requiring it; plain Ruby 4 does not preload it
require "json"
require "phlex/shadcn"
require_relative "scenarios"

module Bench
  # Measures the scenarios and compares allocations with the recorded baseline.
  module Runner
    BASELINE = File.expand_path("baseline.json", __dir__)
    FLAGS = %w[--json --check --record].freeze
    ITERATIONS = 200
    WARMUP = 20
    # Allocations may exceed the baseline by this fraction before --check fails (counts are deterministic, so for tiny counts one
    # extra allocation already fails).
    DEFAULT_TOLERANCE = 0.02

    module_function

    def call(argv)
      unknown = argv - FLAGS
      conflicting = argv.include?("--record") && argv.intersect?(%w[--check --json])
      if unknown.any? || conflicting
        warn "invalid option(s): #{(unknown.empty? ? argv : unknown).join(" ")}; usage: bin/bench [--json] [--check] | bin/bench --record"
        return 2
      end

      results = measure
      baseline = File.exist?(BASELINE) ? JSON.parse(File.read(BASELINE)) : {}
      return record(results:, baseline:) if argv.include?("--record")
      return check(results:, baseline:, json: argv.include?("--json")) if argv.include?("--check")

      report(results:, baseline:, json: argv.include?("--json"))
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

    def check(results:, baseline:, json:)
      drift = environment_drift(baseline)
      unless drift.empty?
        warn "baseline recorded on #{drift.map { |key, version| "#{key} #{version}" }.join(", ")}; running " \
             "#{drift.keys.map { |key| "#{key} #{environment[key]}" }.join(", ")}: allocation gate skipped (run bin/bench --record)"
        report(results:, baseline:, json:)
        return 0
      end

      failures = regressions(results:, baseline:)
      report(results:, baseline:, json:)
      warn failures.join("\n") unless failures.empty?
      failures.empty? ? 0 : 1
    end
  end
end
