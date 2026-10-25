# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

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

  private

  def run_cli(command, root) = Open3.capture2e(RbConfig.ruby, CLI, command, "--root", root)
end
