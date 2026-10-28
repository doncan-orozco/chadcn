# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../dev/catalog/generator"

# lib/chadcn/catalog/entries.json is generated (`bundle exec rake catalog:generate`) from dev/port/scenarios. This test is the same check as
# `rake catalog:check`, inside `rake test`, and proves the check notices a changed scenario.
class CatalogDriftTest < Minitest::Test
  GEM_DIR = File.expand_path("..", __dir__)
  CLI = File.join(GEM_DIR, "dev/catalog/cli.rb")

  def test_committed_entries_match_the_generated_ones
    out, status = run_cli("check", GEM_DIR)

    assert_predicate status, :success?, out
  end

  def test_changing_a_scenario_without_regenerating_fails_the_check
    Dir.mktmpdir("catalog-drift") do |dir|
      FileUtils.mkdir_p(File.join(dir, "dev/port"))
      FileUtils.cp_r(File.join(GEM_DIR, "lib"), dir)
      FileUtils.cp_r(File.join(GEM_DIR, "dev/port/scenarios"), File.join(dir, "dev/port"))
      file = File.join(dir, "dev/port/scenarios/button.json")
      data = JSON.parse(File.read(file, encoding: "UTF-8"))
      data.fetch("scenarios").find { |s| s["id"] == "defaults" }.fetch("tree")["children"] = [ "Changed" ]
      File.write(file, JSON.pretty_generate(data))
      out, status = run_cli("check", dir)

      refute_predicate status, :success?, out
    end
  end

  def test_a_preview_with_a_nested_harness_node_skips_the_component_and_uses_no_sibling
    harness = scenario("default-bar", { "c" => "Chart", "children" => [ { "c" => "Wrap", "children" => [ { "c" => "_BarChart" } ] } ] })
    plain = scenario("basic", { "c" => "Chart", "children" => [ { "c" => "_div", "children" => [ "x" ] } ] })
    data, entry = generated("chart", [ harness, plain ])

    assert_nil entry
    assert_equal [ { component: "chart", reason: "preview scenario uses harness-only nodes" } ], data.skipped
  end

  def test_lowercase_raw_nodes_are_not_harness_nodes
    data, entry = generated("chart", [ scenario("default", { "c" => "Chart", "children" => [ { "c" => "_span" } ] }) ])

    assert_equal "default", entry["scenario_id"]
    assert_empty data.skipped
  end

  def test_the_each_marker_is_not_a_harness_node
    _, entry = generated("combobox", [ scenario("default", { "c" => "Combobox", "children" => [ { "c" => "_Each", "children" => [ "x" ] } ] }) ])

    assert_equal "default", entry["scenario_id"]
  end

  def test_a_probe_pruned_harness_free_default_stays_preferred
    probe = { "c" => "_Probe", "props" => { "data-testid" => "outside" } }
    _, entry = generated("chart", [ scenario("other", { "c" => "Chart" }), scenario("default", { "c" => "Chart", "children" => [ probe ] }) ])

    assert_equal "default", entry["scenario_id"]
    assert_empty entry["tree"]["children"]
  end

  def test_a_dark_sibling_never_replaces_a_harness_preview
    data, entry = generated("chart", [ scenario("default", { "c" => "_BarChart" }), scenario("dark", { "c" => "Chart" }, dark: true) ])

    assert_nil entry
    assert_equal "preview scenario uses harness-only nodes", data.skipped.first[:reason]
  end

  def test_a_component_with_only_dark_scenarios_is_skipped_with_a_reason
    data, entry = generated("chart", [ scenario("dark", { "c" => "Chart" }, dark: true) ])

    assert_nil entry
    assert_equal [ { component: "chart", reason: "no light scenario" } ], data.skipped
  end

  def test_the_real_repository_output_matches_the_committed_catalog
    data = Chadcn::CatalogData.new(GEM_DIR)
    built = data.build
    generated = JSON.parse(built).fetch("entries").map { |entry| entry["component"] }

    assert_equal File.read(File.join(GEM_DIR, Chadcn::CatalogData::OUTPUT), encoding: "UTF-8"), built
    data.skipped.each do |item|
      assert_includes [ "preview scenario uses harness-only nodes", "no light scenario" ], item[:reason]
      refute_includes generated, item[:component]
    end
  end

  def test_the_cli_reports_a_skipped_component_without_changing_the_exit_code
    Dir.mktmpdir("catalog-skip") do |dir|
      FileUtils.mkdir_p(File.join(dir, "dev/port/scenarios"))
      FileUtils.cp_r(File.join(GEM_DIR, "lib"), dir)
      File.write(File.join(dir, "dev/port/scenarios/button.json"), JSON.generate({ "scenarios" => [ scenario("default", { "c" => "_Nope" }) ] }))
      out, status = run_cli("generate", dir)

      assert_predicate status, :success?, out
      assert_includes out, "catalog: skipped button (preview scenario uses harness-only nodes)"
    end
  end

  private

  def scenario(id, tree, dark: false) = { "id" => id, "tree" => tree, "dark" => dark }

  # Builds the entry of one component whose scenarios.json is written to a temp root; ported? is true for it.
  def generated(component, scenarios)
    Dir.mktmpdir("catalog-data") do |dir|
      FileUtils.mkdir_p(File.join(dir, "dev/port/scenarios"))
      File.write(File.join(dir, "dev/port/scenarios/#{component}.json"), JSON.generate({ "scenarios" => scenarios }))
      data = Chadcn::CatalogData.new(dir)
      data.define_singleton_method(:ported?) { |_component| true }
      entry = JSON.parse(data.build).fetch("entries").first
      [ data, entry ]
    end
  end

  def run_cli(command, root) = Open3.capture2e(RbConfig.ruby, CLI, command, "--root", root)
end
