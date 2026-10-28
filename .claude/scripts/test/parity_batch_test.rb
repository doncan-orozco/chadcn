# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# parity_batch.rb --only PREFIXES: the browser gates run only the scenario ids that start with one of the prefixes (a chart family
# gates on its own ids) and the others are reported as skipped with the reason. The runner is a fake `node` that records its
# arguments, so no browser or dev server is needed.
class ParityBatchTest < ActiveSupport::TestCase
  SCRIPT = TOOLING_ROOT.join(".claude/scripts/shadcn/parity_batch.rb").to_s
  FAKE_NODE = <<~SH
    #!/bin/sh
    echo "$@" >> "$FAKE_NODE_LOG"
    echo '{"pass": true, "diffs": []}'
  SH

  def run_batch(*args)
    Dir.mktmpdir do |dir|
      fake = File.join(dir, "bin")
      Dir.mkdir(fake)
      File.write(File.join(fake, "node"), FAKE_NODE)
      File.chmod(0o755, File.join(fake, "node"))
      log = File.join(dir, "node.log")
      env = { "PATH" => "#{fake}:#{ENV.fetch('PATH')}", "FAKE_NODE_LOG" => log, "PARITY_REACT_URL" => "http://x", "PARITY_PHLEX_URL" => "http://y" }
      stdout, _, status = Open3.capture3(env, RbConfig.ruby, SCRIPT, "--no-servers", "--out", File.join(dir, "out"), *args)
      [ JSON.parse(stdout), File.exist?(log) ? File.readlines(log, chomp: true) : [], status ]
    end
  end

  def scenario_ids(component)
    JSON.parse(TOOLING_ROOT.join("dev/port/scenarios/#{component}.json").read).fetch("scenarios").map { |scenario| scenario["id"] }
  end

  test "--only passes the matching ids to the runner and reports the others as skipped with a reason" do
    ids = scenario_ids("button")
    prefix = ids.first[0, 3]
    matching = ids.select { |id| id.start_with?(prefix) }
    report, calls, status = run_batch("--components", "button", "--only", prefix)

    assert_predicate status, :success?
    assert_equal 1, calls.size
    assert_equal matching.join(","), calls.first[/--only (\S+)/, 1]
    gate = report.dig("components", "button", "gates", "g2")
    assert_equal ids.size - matching.size, gate.dig("skipped_scenarios", "count")
    assert_includes gate.dig("skipped_scenarios", "reason"), prefix
  end

  test "--only takes a comma list of prefixes" do
    ids = scenario_ids("button")
    prefixes = ids.map { |id| id[0, 3] }.uniq.first(2)
    expected = ids.select { |id| prefixes.any? { |prefix| id.start_with?(prefix) } }
    _, calls, = run_batch("--components", "button", "--only", prefixes.join(","))

    assert_equal expected.join(","), calls.first[/--only (\S+)/, 1]
  end

  test "--only matching nothing skips the gate with a reason instead of running every scenario" do
    report, calls, status = run_batch("--components", "button", "--only", "nonexistent__")

    assert_predicate status, :success?
    assert_empty calls
    assert_includes report.dig("components", "button", "gates", "g2", "skipped"), "nonexistent__"
  end

  test "without --only the runner gets no --only and nothing is reported skipped" do
    report, calls, = run_batch("--components", "button")

    refute_includes calls.first, "--only"
    assert_nil report.dig("components", "button", "gates", "g2", "skipped_scenarios")
  end
end
