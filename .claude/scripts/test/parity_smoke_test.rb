# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../shadcn/parity_smoke"

# parity_smoke.rb: the subset CI runs on every push (the `default` scenarios of every component, or the first scenario of a component
# without one) and the runner around parity_batch.rb (one call per component, a wall-clock budget). The runner tests use a fake `node`
# that records its arguments, so no browser or dev server is needed.
class ParitySmokeTest < ActiveSupport::TestCase
  SCRIPT = TOOLING_ROOT.join(".claude/scripts/shadcn/parity_smoke.rb").to_s
  SCENARIOS = TOOLING_ROOT.join("dev/port/scenarios")
  FAKE_NODE = <<~SH
    #!/bin/sh
    echo "$@" >> "$FAKE_NODE_LOG"
    if [ -n "$FAKE_NODE_DIFF" ]; then echo '{"pass": false, "diffs": [{"kind": "CLASS"}]}'; else echo '{"pass": true, "diffs": []}'; fi
  SH

  def write_scenarios(dir, component, ids)
    File.write(File.join(dir, "#{component}.json"), JSON.generate("scenarios" => ids.map { |id| { "id" => id } }))
  end

  def run_smoke(*args, env: {})
    Dir.mktmpdir do |dir|
      fake = File.join(dir, "bin")
      Dir.mkdir(fake)
      File.write(File.join(fake, "node"), FAKE_NODE)
      File.chmod(0o755, File.join(fake, "node"))
      log = File.join(dir, "node.log")
      env = { "PATH" => "#{fake}:#{ENV.fetch('PATH')}", "FAKE_NODE_LOG" => log, "PARITY_REACT_URL" => "http://x",
              "PARITY_PHLEX_URL" => "http://y" }.merge(env)
      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, SCRIPT, "--no-servers", "--out", File.join(dir, "out"), *args)
      [ JSON.parse(stdout), File.exist?(log) ? File.readlines(log, chomp: true) : [], status, stderr ]
    end
  end

  def runner_ids(call) = call[/--only (\S+)/, 1].split(",")

  def component_of(call) = call[/--component (\S+)/, 1]

  test "a component with default scenarios contributes exactly the ids starting with default" do
    Dir.mktmpdir do |dir|
      write_scenarios(dir, "badge", %w[variant-outline defaults defaults__dark default-open__click other])
      assert_equal({ "badge" => %w[defaults defaults__dark default-open__click] }, ParitySmoke.subset(dir))
    end
  end

  test "a component without a default scenario contributes its first scenario and the ids that extend it" do
    Dir.mktmpdir do |dir|
      write_scenarios(dir, "dialog", %w[closed__rest closed__rest__dark closed__trigger-hover open__rest])
      assert_equal({ "dialog" => %w[closed__rest closed__rest__dark] }, ParitySmoke.subset(dir))
    end
  end

  test "primitive scenario files and files without scenarios are left out" do
    Dir.mktmpdir do |dir|
      write_scenarios(dir, "_primitives-typeahead", %w[default])
      write_scenarios(dir, "empty", [])
      write_scenarios(dir, "card", %w[default__all-parts])
      assert_equal %w[card], ParitySmoke.subset(dir).keys
    end
  end

  test "every component scenario file of the port has a non-empty smoke subset" do
    components = Dir[SCENARIOS.join("*.json").to_s].map { |file| File.basename(file, ".json") }.reject { |name| name.start_with?("_") }
    subset = ParitySmoke.subset(SCENARIOS.to_s)

    assert_equal components.sort, subset.keys
    subset.each { |component, ids| assert_predicate ids, :any?, component }
  end

  test "the runner gates each component on exactly its subset, one batch per component" do
    report, calls, status = run_smoke("--components", "button,dialog")

    assert_predicate status, :success?
    assert report["pass"]
    subset = ParitySmoke.subset(SCENARIOS.to_s)
    assert_equal %w[button dialog], calls.map { |call| component_of(call) }
    calls.each { |call| assert_equal subset.fetch(component_of(call)), runner_ids(call) }
    assert_equal subset["dialog"], report.dig("components", "dialog", "scenarios")
  end

  test "a diff in any component exits 1 and names the component" do
    report, _, status = run_smoke("--components", "button", env: { "FAKE_NODE_DIFF" => "1" })

    assert_equal 1, status.exitstatus
    refute report["pass"]
    assert_equal false, report.dig("components", "button", "pass")
    assert_equal 1, report.dig("components", "button", "diffs")
  end

  test "an exhausted budget stops before the next component and exits 2" do
    report, calls, status = run_smoke("--components", "button,dialog", "--budget", "0")

    assert_equal 2, status.exitstatus
    assert_empty calls
    assert_includes report["error"], "budget"
    assert_equal %w[button dialog], report["not_run"]
  end

  test "--list prints the subset without running anything" do
    report, calls, status = run_smoke("--list", "--components", "dialog")

    assert_predicate status, :success?
    assert_empty calls
    assert_equal({ "dialog" => ParitySmoke.subset(SCENARIOS.to_s)["dialog"] }, report["subset"])
  end

  test "an unknown component is an argument error" do
    report, calls, status = run_smoke("--components", "no-such-component")

    assert_equal 2, status.exitstatus
    assert_empty calls
    assert_includes report["error"], "no-such-component"
  end
end
