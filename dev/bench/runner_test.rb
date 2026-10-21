# frozen_string_literal: true

# Run with: cd gems/phlex-shadcn && ruby dev/bench/runner_test.rb
require "minitest/autorun"
require "tempfile"
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

    assert_equal %w[ok ok], rows.map(&:last)
  end

  def test_too_small_a_drop_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "button" => 30.0 })

    assert_equal "too small", rows.first.last
    assert_in_delta 28.07, rows.first[3], 0.01
  end

  def test_unknown_scenario_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: EARLIER, expectations: { "nope" => 0.0 })

    assert_equal "unknown scenario", rows.first.last
  end

  def test_scenario_missing_from_baseline_fails
    rows = Bench::Runner.improvements(results: RESULTS, baseline: { **CURRENT, "allocations" => {} }, expectations: { "button" => 0.0 })

    assert_equal "no baseline", rows.first.last
  end

  def test_zero_percent_passes_when_unchanged
    rows = Bench::Runner.improvements(results: RESULTS, baseline: { **CURRENT, "allocations" => { "button" => 41 } }, expectations: { "button" => 0.0 })

    assert_equal "ok", rows.first.last
  end

  def test_improvement_exit_codes_and_table
    with_baseline(EARLIER) do |path|
      out, = capture_io { assert_equal 0, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 25.0 }, source: path, json: false) }

      assert_match(/button\s+57\s+41\s+28\.1\s+25\.0\s+ok/, out)
      out, = capture_io { assert_equal 1, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 50.0 }, source: path, json: false) }

      assert_match(/too small/, out)
    end
  end

  def test_baseline_from_another_ruby_is_reported_and_fails_not_skips
    with_baseline(EARLIER.merge("ruby" => "0.0.1")) do |path|
      status = nil
      out, err = capture_io { status = Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 0.0 }, source: path, json: false) }

      assert_equal 1, status
      assert_match(/ruby 0\.0\.1/, err)
      assert_match(/not verified/, err)
      assert_empty out
    end
  end

  def test_unreadable_baseline_fails
    status = nil
    _, err = capture_io { status = Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 0.0 }, source: "no-such-rev-or-file", json: false) }

    assert_equal 1, status
    assert_match(/cannot read a baseline/, err)
  end

  def test_git_revision_baseline_is_read
    skip "no git history available" unless system("git", "rev-parse", "--verify", "-q", "HEAD", out: File::NULL, err: File::NULL)

    assert_kind_of Hash, Bench::Runner.load_baseline("HEAD")
  end

  def test_json_mode_prints_only_json
    with_baseline(EARLIER) do |path|
      out, = capture_io { assert_equal 0, Bench::Runner.improvement(results: RESULTS, expectations: { "button" => 25.0 }, source: path, json: true) }
      parsed = JSON.parse(out)

      assert_equal "ok", parsed.dig("improvement", "button", "verdict")
      assert_equal 41, parsed.dig("results", "button", "allocations")
    end
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

  def with_baseline(content)
    Tempfile.create([ "baseline", ".json" ]) do |file|
      file.write(JSON.generate(content))
      file.flush
      yield file.path
    end
  end
end
