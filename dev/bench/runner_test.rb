# frozen_string_literal: true

# Run with: ruby dev/bench/runner_test.rb
require "minitest/autorun"
require "fileutils"
require "tempfile"
require "tmpdir"
require_relative "runner"

class BenchRunnerTest < Minitest::Test
  CURRENT = { "ruby" => RUBY_VERSION, "phlex" => Phlex::VERSION }.freeze
  RESULTS = { "button" => { "us" => 1.0, "allocations" => 41 }, "card" => { "us" => 1.0, "allocations" => 119 } }.freeze
  EARLIER = { **CURRENT, "allocations" => { "button" => 57, "card" => 197 } }.freeze
  BASELINE = { "tolerance" => 0.02, "allocations" => { "button" => 100 } }.freeze

  def test_within_tolerance_passes
    assert_empty Bench::Runner.regressions(results: { "button" => { "allocations" => 102 } }, baseline: BASELINE)
  end

  def test_over_tolerance_fails
    assert_match(/button: 103 allocations/, Bench::Runner.regressions(results: { "button" => { "allocations" => 103 } }, baseline: BASELINE).first)
  end

  def test_missing_baseline_fails_loud
    assert_match(/card: no baseline/, Bench::Runner.regressions(results: { "card" => { "allocations" => 1 } }, baseline: BASELINE).first)
  end

  def test_unknown_flag_exits_two
    status = nil
    capture_io { status = Bench::Runner.call(["--chek"]) }

    assert_equal 2, status
  end

  def test_matching_environment_has_no_drift
    assert_empty Bench::Runner.environment_drift(CURRENT)
  end

  def test_other_ruby_is_drift
    assert_equal({ "ruby" => "0.0.1" }, Bench::Runner.environment_drift(CURRENT.merge("ruby" => "0.0.1")))
  end

  def test_unstamped_baseline_is_drift
    assert_equal %w[ruby phlex], Bench::Runner.environment_drift({}).keys
  end

  def test_record_with_check_exits_two
    status = nil
    capture_io { status = Bench::Runner.call(%w[--record --check]) }

    assert_equal 2, status
  end

  def test_reference_renders_the_same_html_as_button
    scenarios = Bench::Scenarios::ALL

    assert_equal scenarios["button"].call.call, scenarios["reference"].call.call
  end

  def test_expectations_parse_percentages
    assert_equal({ "button" => 25.0, "card" => 20.5 }, Bench::Runner.parse_expectations("button=25,card=20.5"))
  end

  def test_malformed_expectations_are_rejected
    [ "", "button", "button=", "=5", "button=abc", "button=-5", "button=101", "button=5,", "button=5,button=6", "button=5=6" ].each do |text|
      assert_nil Bench::Runner.parse_expectations(text), text.inspect
    end
  end

  def test_malformed_expectations_exit_two_with_usage
    status = nil
    _, err = capture_io { status = Bench::Runner.call(%w[--check --expect-improvement button]) }

    assert_equal 2, status
    assert_match(/usage: bin\/bench/, err)
  end

  def test_flag_without_value_exits_two
    status = nil
    capture_io { status = Bench::Runner.call(%w[--check --expect-improvement]) }

    assert_equal 2, status
  end

  def test_expect_improvement_needs_check
    assert_match(/needs --check/, Bench::Runner.parse(%w[--expect-improvement button=5]))
  end

  def test_against_needs_expect_improvement
    assert_match(/needs --expect-improvement/, Bench::Runner.parse(%w[--check --against x.json]))
  end

  def test_record_with_expect_improvement_is_invalid
    assert_kind_of String, Bench::Runner.parse(%w[--record --expect-improvement button=5])
  end

  def test_help_documents_the_flag
    out, = capture_io { assert_equal 0, Bench::Runner.call(["--help"]) }

    assert_match(/--expect-improvement SCENARIO=PERCENT/, out)
    assert_match(/--against/, out)
  end

  def test_enough_improvement_passes
    rows = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "button" => 25.0, "card" => 20.0 })

    assert_equal %w[ok ok], rows.map(&:verdict)
  end

  def test_too_small_a_drop_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "button" => 30.0 })

    assert_equal "too small", rows.first.verdict
    assert_in_delta 28.07, rows.first.drop, 0.01
  end

  def test_unknown_scenario_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "nope" => 0.0 })

    assert_equal "unknown scenario", rows.first.verdict
  end

  def test_scenario_missing_from_baseline_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: { **CURRENT, "allocations" => {} }, expectations: { "button" => 0.0 })

    assert_equal "no baseline", rows.first.verdict
  end

  def test_zero_percent_passes_when_unchanged
    rows = Bench::Runner.improvements(results: RESULTS, baseline: { **CURRENT, "allocations" => { "button" => 41 } }, expectations: { "button" => 0.0 })

    assert_equal "ok", rows.first.verdict
  end

  def test_improvement_exit_codes_and_table
    out, = capture_io { assert_equal 0, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 25.0 }, baseline: EARLIER, json: false) }

    assert_match(/button\s+57\s+41\s+28\.1\s+25\.0\s+ok/, out)
    out, = capture_io { assert_equal 1, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 50.0 }, baseline: EARLIER, json: false) }

    assert_match(/too small/, out)
  end

  def test_improvement_rows_are_named
    row = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "button" => 25.0 }).first

    assert_equal [ "button", 57, 41, 25.0, "ok" ], [ row.name, row.before, row.now, row.wanted, row.verdict ]
  end

  def test_baseline_from_another_ruby_is_reported_and_fails_not_skips
    with_baseline(EARLIER.merge("ruby" => "0.0.1")) do |path|
      message = Bench::Runner.prepare_improvement(expectations: { "button" => 0.0 }, source: path)

      assert_match(/ruby 0\.0\.1/, message)
      assert_match(/not verified/, message)
    end
  end

  def test_unknown_scenario_is_rejected_before_measuring
    with_baseline(EARLIER) do |path|
      assert_match(/unknown scenario\(s\) nope/, Bench::Runner.prepare_improvement(expectations: { "nope" => 0.0 }, source: path))
    end
  end

  def test_prepare_improvement_returns_the_baseline
    with_baseline(EARLIER) { |path| assert_equal EARLIER, Bench::Runner.prepare_improvement(expectations: { "button" => 0.0 }, source: path) }
  end

  def test_call_fails_fast_without_measuring
    forbidding_measurement do
      with_baseline(EARLIER.merge("ruby" => "0.0.1")) do |path|
        status = nil
        _, err = capture_io { status = Bench::Runner.call([ "--check", "--expect-improvement", "button=0", "--against", path ]) }

        assert_equal 1, status
        assert_match(/not verified/, err)
      end
      status = nil
      _, err = capture_io { status = Bench::Runner.call(%w[--check --expect-improvement nope=0 --against no-such-file]) }

      assert_equal 1, status
      assert_match(/cannot read a baseline/, err)
    end
  end

  def test_repeated_expect_improvement_is_merged
    options = Bench::Runner.parse(%w[--check --expect-improvement button=25 --expect-improvement card=20])

    assert_equal({ "button" => 25.0, "card" => 20.0 }, options[:expectations])
  end

  def test_scenario_named_in_two_expect_improvement_flags_exits_two
    status = nil
    _, err = capture_io { status = Bench::Runner.call(%w[--check --expect-improvement button=25 --expect-improvement button=0,card=1]) }

    assert_equal 2, status
    assert_match(/button more than once/, err)
  end

  def test_repeated_against_exits_two
    status = nil
    _, err = capture_io { status = Bench::Runner.call(%w[--check --expect-improvement button=1 --against a.json --against b.json]) }

    assert_equal 2, status
    assert_match(/--against given more than once/, err)
  end

  def test_help_documents_the_repeated_flag
    out, = capture_io { Bench::Runner.call(["--help"]) }

    assert_match(/may be repeated/, out)
  end

  def test_unreadable_baseline_fails
    assert_match(/cannot read a baseline/, Bench::Runner.prepare_improvement(expectations: { "button" => 0.0 }, source: "no-such-rev-or-file"))
  end

  def test_git_revision_baseline_is_read
    skip "git is not available" unless system("git", "--version", out: File::NULL, err: File::NULL)

    outer = ENV.to_h.select { |key, _| key.start_with?("GIT_") }
    outer.each_key { |key| ENV.delete(key) }
    Dir.mktmpdir do |repo|
      FileUtils.mkdir_p(File.join(repo, "dev/bench"))
      File.write(File.join(repo, "dev/bench/baseline.json"), JSON.generate(EARLIER))
      git = %w[git -c core.hooksPath=/dev/null -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false -c init.defaultBranch=main]
      assert system(*git, "init", "-q", repo)
      assert system(*git, "-C", repo, "add", "dev/bench/baseline.json")
      assert system(*git, "-C", repo, "commit", "-q", "-m", "baseline")

      assert_equal EARLIER, Bench::Runner.load_baseline("HEAD", repo:)
      assert_match(/cannot read a baseline/, Bench::Runner.load_baseline("no-such-rev", repo:))
    end
  ensure
    outer&.each { |key, value| ENV[key] = value }
  end

  def test_json_mode_prints_only_json
    out, = capture_io { assert_equal 0, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 25.0 }, baseline: EARLIER, json: true) }
    parsed = JSON.parse(out)

    assert_equal "ok", parsed.dig("improvement", "button", "verdict")
    assert_equal 41, parsed.dig("results", "button", "allocations")
  end

  def test_non_object_baseline_is_a_readable_failure
    with_baseline([]) { |path| assert_match(/not a JSON object/, Bench::Runner.load_baseline(path)) }
  end

  def test_option_like_revision_is_not_passed_to_git_as_an_option
    assert_match(/cannot read a baseline/, Bench::Runner.load_baseline("-p"))
  end

  def test_baseline_with_non_integer_allocations_is_a_readable_failure
    with_baseline({ **CURRENT, "allocations" => { "button" => "57" } }) { |path| assert_match(/map scenarios to integers/, Bench::Runner.load_baseline(path)) }
  end

  def test_invalid_baselines_are_described
    {
      "not a JSON object" => [],
      "allocations must map scenarios to integers" => { "allocations" => [ 1 ] },
      "tolerance must be a number from 0 up" => { "tolerance" => "2%" },
      "ruby and phlex must be version strings" => { "ruby" => 4 }
    }.each do |problem, baseline|
      assert_equal problem, Bench::Runner.baseline_problem(baseline), baseline.inspect
    end
    assert_nil Bench::Runner.baseline_problem(EARLIER)
    assert_nil Bench::Runner.baseline_problem({})
  end

  def test_malformed_default_baseline_exits_non_zero_without_measuring
    [ "[]", "not json", JSON.generate({ "allocations" => { "button" => "1" } }) ].each do |content|
      with_default_baseline(content) do
        forbidding_measurement do
          %w[--check --json].each do |flag|
            status = nil
            _, err = capture_io { status = Bench::Runner.call([ flag ]) }

            assert_equal 1, status, content
            assert_match(/cannot read a baseline/, err)
          end
        end
      end
    end
  end

  def test_expect_improvement_against_a_malformed_default_baseline_fails_without_measuring
    with_default_baseline("[]") do
      forbidding_measurement do
        status = nil
        _, err = capture_io { status = Bench::Runner.call(%w[--check --expect-improvement button=0]) }

        assert_equal 1, status
        assert_match(/not a JSON object/, err)
      end
    end
  end

  def test_unstamped_default_baseline_skips_the_check_with_a_warning
    with_default_baseline(JSON.generate({ "allocations" => { "button" => 1 } })) do
      status = nil
      _, err = capture_io { status = Bench::Runner.call(%w[--check]) }

      assert_equal 0, status
      assert_match(/ruby unknown, phlex unknown/, err)
    end
  end

  def test_record_repairs_a_malformed_baseline
    with_default_baseline("[]") do |path|
      _, err = capture_io { assert_equal 0, Bench::Runner.call(%w[--record]) }
      recorded = JSON.parse(File.read(path))

      assert_match(/rewriting it/, err)
      assert_equal Bench::Scenarios::ALL.keys, recorded.fetch("allocations").keys
      assert_equal CURRENT.merge("tolerance" => Bench::Runner::DEFAULT_TOLERANCE), recorded.slice("ruby", "phlex", "tolerance")
    end
  end

  def test_check_skips_on_drift_with_exit_zero
    status = nil
    _, err = capture_io { status = Bench::Runner.check(results: RESULTS, baseline: { "allocations" => {} }, json: false) }

    assert_equal 0, status
    assert_match(/allocation gate skipped/, err)
  end

  def test_check_fails_on_regression
    status = nil
    baseline = { **CURRENT, "allocations" => { "button" => 10, "card" => 119 } }
    _, err = capture_io { status = Bench::Runner.check(results: RESULTS, baseline:, json: false) }

    assert_equal 1, status
    assert_match(/button: 41 allocations/, err)
  end

  def test_check_passes_within_baseline
    status = nil
    capture_io { status = Bench::Runner.check(results: RESULTS, baseline: { **CURRENT, "allocations" => { "button" => 41, "card" => 119 } }, json: false) }

    assert_equal 0, status
  end

  private

  def forbidding_measurement
    original = Bench::Runner.method(:measure)
    Bench::Runner.define_singleton_method(:measure) { raise "measured before the checks" }
    yield
  ensure
    Bench::Runner.define_singleton_method(:measure, original)
  end

  def with_default_baseline(content)
    Tempfile.create([ "default-baseline", ".json" ]) do |file|
      file.write(content)
      file.flush
      original = Bench::Runner::BASELINE
      Bench::Runner.send(:remove_const, :BASELINE)
      Bench::Runner.const_set(:BASELINE, file.path)
      begin
        yield file.path
      ensure
        Bench::Runner.send(:remove_const, :BASELINE)
        Bench::Runner.const_set(:BASELINE, original)
      end
    end
  end

  def with_baseline(content)
    Tempfile.create([ "baseline", ".json" ]) do |file|
      file.write(JSON.generate(content))
      file.flush
      yield file.path
    end
  end
end
