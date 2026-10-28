# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# llms.txt, llms-full.txt and skills/chadcn/SKILL.md are generated (`bundle exec rake llms:generate`) from the YARD docs and the
# Stimulus controllers. This test is the same check as `rake llms:check`, inside `rake test`, and proves the check notices a changed component.
class LlmsDriftTest < Minitest::Test
  GEM_DIR = File.expand_path("..", __dir__)
  CLI = File.join(GEM_DIR, "dev/llms/cli.rb")

  def test_committed_llms_files_match_the_generated_ones
    out, status = run_cli("check", GEM_DIR)

    assert_predicate status, :success?, out
  end

  def test_llms_full_lists_every_component_the_registry_knows
    components = with_clean_yard_registry do
      YARD.parse(Dir[File.join(GEM_DIR, "lib/**/*.rb")].reject { |path| path.end_with?("icons/catalog.rb") })
      all = YARD::Registry.all(:class).select { |c| c.namespace.path == "Chadcn" && c.superclass&.path == "Chadcn::Base" }
      all.reject { |c| c.tag(:api)&.text == "private" || c.visibility != :public || c.name == :Icon }.map(&:name)
    end
    full = File.read(File.join(GEM_DIR, "llms-full.txt"))

    assert_equal 55, components.size
    components.each do |name|
      assert_includes full, "## #{name}\n", "#{name} is missing from llms-full.txt"
      assert_includes full, "Chadcn::#{name}.new(", "#{name} has no constructor line"
    end
  end

  def test_no_generated_file_has_a_doubled_comma
    %w[test/fixtures/public_api.txt llms.txt llms-full.txt skills/chadcn/SKILL.md].each do |file|
      refute_includes File.read(File.join(GEM_DIR, file), encoding: "UTF-8"), ",,", "#{file} has a doubled comma in a signature"
    end
  end

  def test_llms_txt_follows_the_convention
    lines = File.read(File.join(GEM_DIR, "llms.txt")).lines

    assert_match(/\A# \S/, lines.first)
    assert_match(/\A> \S/, lines[2])
    assert(lines.any? { |line| line.start_with?("## ") })
    assert(lines.grep(/\A- \[/).all? { |line| line.match?(%r{\A- \[[^\]]+\]\(https://[^)]+\)}) })
  end

  def test_changing_a_component_keyword_without_regenerating_fails_the_check
    Dir.mktmpdir("llms-drift") do |dir|
      %w[lib app llms.txt llms-full.txt skills].each { |entry| FileUtils.cp_r(File.join(GEM_DIR, entry), dir) }
      button = File.join(dir, "lib/chadcn/button.rb")
      source = File.read(button)
      mutated = source.sub("as_child: false, **attrs)\n    @variant", "as_child: false, loading: false, **attrs)\n    @variant")

      refute_equal source, mutated, "the mutation did not apply: update this test to the current Button#initialize"
      File.write(button, mutated)
      out, status = run_cli("check", dir)

      refute_predicate status, :success?, out
      assert_includes out, "llms-full.txt"
    end
  end

  def test_stimulus_values_and_events_are_complete_for_known_controllers
    full = File.read(File.join(GEM_DIR, "llms-full.txt"))
    dialog = full[/^Stimulus: `chadcn--dialog`.*$/]

    %w[open controlled modal id].each { |value| assert_includes dialog, "`#{value}`" }
    %w[open-change escape-key-down pointer-down-outside focus-outside interact-outside].each { |event| assert_includes dialog, "`#{event}`" }
    slider = full[/^Stimulus: `chadcn--slider`.*$/]

    %w[max step min-steps-between-thumbs preserve-thumb-order form].each { |value| assert_includes slider, "`#{value}`" }
    assert_includes full[/^Stimulus: `chadcn--alert-dialog`.*$/], "`open-change`"
    context_menu = full[/^Stimulus: `chadcn--context-menu`.*$/]

    %w[open-change select checked-change value-change escape-key-down close-auto-focus].each { |event| assert_includes context_menu, "`#{event}`" }
  end

  def test_changing_a_stimulus_value_without_regenerating_fails_the_check
    Dir.mktmpdir("llms-drift") do |dir|
      %w[lib app llms.txt llms-full.txt skills].each { |entry| FileUtils.cp_r(File.join(GEM_DIR, entry), dir) }
      js = File.join(dir, "app/javascript/controllers/chadcn/dialog_controller.js")
      source = File.read(js)
      mutated = source.sub("static values = { open: Boolean,", "static values = { open: Boolean, dismissible: Boolean,")

      refute_equal source, mutated, "the mutation did not apply: update this test to the current dialog controller"
      File.write(js, mutated)
      out, status = run_cli("check", dir)

      refute_predicate status, :success?, out
    end
  end

  private

  # The YARD registry is process-wide state: start from an empty one and leave it empty, whatever the block does.
  def with_clean_yard_registry
    require "yard"
    YARD::Registry.clear
    yield
  ensure
    YARD::Registry.clear
  end

  def run_cli(command, root) = Open3.capture2e(RbConfig.ruby, CLI, command, "--root", root)
end
