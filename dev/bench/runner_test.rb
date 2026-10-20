# frozen_string_literal: true

# Run with: cd gems/phlex-shadcn && env -u BUNDLE_GEMFILE bundle exec ruby dev/bench/runner_test.rb
require "minitest/autorun"
require_relative "runner"

class BenchRunnerTest < Minitest::Test
  CURRENT = { "ruby" => RUBY_VERSION, "phlex" => Phlex::VERSION }.freeze
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
end
