# frozen_string_literal: true

# Spike for the eject generator: proves that a host directory of component files takes precedence over the gem's
# lib/chadcn/** for the same constant. Decision and production consequences: dev/decisions/eject-override.md.
#
#   cd gems/chadcn && env -u BUNDLE_GEMFILE bundle exec ruby -Ilib -Itest dev/spikes/eject/override_test.rb
#
# Each scenario runs in a child process (harness.rb): Zeitwerk loaders and the constants they define are global state.
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"

class EjectOverrideTest < Minitest::Test
  HARNESS = File.expand_path("harness.rb", __dir__)
  LIB = File.expand_path("../../../lib", __dir__)

  def run_scenario(fixture, load_mode, ignore_timing = "ignore_before_setup", reload = nil)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", LIB, HARNESS, fixture, load_mode, ignore_timing, *reload)
    assert_predicate status, :success?, "harness failed: #{err}"
    JSON.parse(out.lines.last)
  end

  %w[lazy eager].each do |mode|
    define_method(:"test_baseline_without_overrides_loads_the_gem_button_#{mode}") do
      result = run_scenario("none", mode)

      assert_nil result["eager_error"]
      assert_includes result["button"], 'data-variant="default"'
      assert_nil result["error"]
    end

    define_method(:"test_leaf_override_takes_precedence_#{mode}") do
      result = run_scenario("leaf", mode)

      assert_nil result["eager_error"]
      assert_nil result["error"]
      assert_includes result["button"], 'data-ejected="leaf"'
      assert_includes result["button_source"], "fixtures/leaf/button.rb"
    end

    define_method(:"test_leaf_override_is_used_by_gem_components_that_render_it_#{mode}") do
      result = run_scenario("leaf", mode)

      assert result["footer_uses_ejected_button"], "Dialog::Footer must render the ejected Button"
      assert_equal "./lib/chadcn/card.rb", result["card_source"]
    end

    define_method(:"test_compound_root_override_takes_precedence_as_a_unit_#{mode}") do
      result = run_scenario("root", mode)

      assert_nil result["eager_error"]
      assert_nil result["error"]
      assert_equal "root", result["dialog_ejected"]
      assert_equal "root_content", result["dialog_content_ejected"]
      assert_includes result["dialog_title_source"], "fixtures/root/dialog/title.rb"
      assert_includes result["button"], "bg-primary", "components that are not ejected still load from the gem"
      assert_equal "./lib/chadcn/card.rb", result["card_source"]
    end

    define_method(:"test_nested_part_override_keeps_the_rest_of_the_component_in_the_gem_#{mode}") do
      result = run_scenario("nested", mode)

      assert_nil result["eager_error"]
      assert_nil result["error"]
      assert_nil result["dialog_ejected"], "Dialog itself still comes from the gem"
      assert_equal "nested", result["dialog_content_ejected"]
      assert_equal "./lib/chadcn/dialog/title.rb", result["dialog_title_source"]
    end
  end

  def test_ignoring_after_setup_cannot_shadow_a_top_level_gem_file
    # Why the override directory must be known before the gem loader's setup (decision note, "When the loader learns").
    result = run_scenario("leaf", "lazy", "ignore_after_setup")

    assert_nil result["ignore_after_error"], "Zeitwerk accepts ignore after setup and then does nothing with it"
    assert_includes result["button"], 'data-variant="default"', "the gem Button wins: its autoload was registered at setup"
    refute_includes result["button"], "data-ejected"
  end

  def test_without_ignore_the_gem_wins_silently_for_leaf_and_root
    %w[leaf root].each do |fixture|
      result = run_scenario(fixture, "eager", "ignore_none")

      assert_nil result["eager_error"], fixture
      assert_includes result["button"], 'data-variant="default"'
      assert_nil result["dialog_ejected"], "override is dead code without the gem-side ignore (#{fixture})"
    end
  end

  def test_reload_of_both_loaders_keeps_the_override
    result = run_scenario("leaf", "lazy", "ignore_before_setup", "reload")

    assert_nil result["error"]
    assert result["after_reload_button"]
    assert result["after_reload_footer"]
  end

  def test_reloading_only_the_override_loader_keeps_a_leaf_override
    result = run_scenario("leaf", "lazy", "ignore_before_setup", "reload_override_only")

    assert_nil result["error"]
    assert result["after_reload_button"]
    assert result["after_reload_footer"]
  end

  def test_reloading_only_the_override_loader_keeps_a_nested_part_under_the_gem_namespace
    result = run_scenario("nested", "eager", "ignore_before_setup", "reload_override_only")

    assert_nil result["error"]
    assert_equal "nested", result["after_reload_content"]
    assert_equal "./lib/chadcn/dialog.rb", result["after_reload_dialog_source"]
  end
end
