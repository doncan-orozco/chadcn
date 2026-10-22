# frozen_string_literal: true

require "stringio"
require_relative "engine_helper"

# tailwindcss-rails writes `app/assets/builds/tailwind/<engine>.css`, a stub whose absolute `@import` only the Tailwind CLI can resolve.
# That directory is inside the host's own `app/assets/builds` root, so `stylesheet_link_tag :app` would link it and the browser would 404
# on the import (and the stub would disclose the gem's filesystem path). It is Tailwind input, never a browser stylesheet.
class EngineTest::StubCss < Minitest::Test
  BUILDS = EngineTest::ROOT.join("app/assets/builds")

  def setup
    FileUtils.rm_rf(BUILDS)
    FileUtils.mkdir_p(BUILDS.join("tailwind"))
    File.write(BUILDS.join("tailwind.css"), "/* compiled */")
    File.write(BUILDS.join("tailwind/chadcn.css"), %(@import "/abs/engine.css";))
    File.write(BUILDS.join("tailwind/other-engine.css"), %(@import "/abs/other.css";))
    File.write(BUILDS.join("application.css"), "/* app */")
  end

  def teardown = FileUtils.rm_rf(BUILDS)

  def load_path
    Propshaft::LoadPath.new([ BUILDS ], compilers: EngineTest::Application.assets.load_path.compilers)
  end

  def test_the_filter_hooks_a_method_this_propshaft_still_defines
    assert Propshaft::LoadPath.private_method_defined?(:without_dotfiles),
           "Propshaft renamed LoadPath#without_dotfiles: move TailwindStubFilter to the new hook"
    assert_equal 1, Propshaft::LoadPath.instance_method(:without_dotfiles).arity, "Propshaft changed the hook's signature"
    assert(Propshaft::LoadPath.ancestors.any? { |mod| mod.name == "Chadcn::Engine::TailwindStubFilter" })
  end

  def test_propshafts_own_dotfile_filter_still_runs
    File.write(BUILDS.join(".keep"), "")

    assert_nil load_path.find(".keep")
  end

  def test_the_compiled_application_css_is_still_served
    assert load_path.find("tailwind.css")
    assert load_path.find("application.css")
  end

  def test_the_engine_stub_is_not_among_the_served_assets
    assert_nil load_path.find("tailwind/chadcn.css")
    assert_nil load_path.find("tailwind/other-engine.css")
    refute_includes load_path.assets.map { |asset| asset.logical_path.to_s }, "tailwind/chadcn.css"
  end

  def test_stylesheet_link_tag_app_does_not_list_the_stub
    css = load_path.asset_paths_by_glob("#{EngineTest::ROOT.join('app/assets')}/**/*.css")

    assert_equal %w[application.css tailwind.css], css
  end

  def test_stylesheet_link_tag_all_does_not_list_the_stub
    assert_equal %w[application.css tailwind.css], load_path.asset_paths_by_type("css")
  end

  def test_other_files_in_a_tailwind_directory_outside_the_builds_are_untouched
    elsewhere = EngineTest::ROOT.join("vendor/assets")
    FileUtils.mkdir_p(elsewhere.join("tailwind"))
    File.write(elsewhere.join("tailwind/keep.css"), "x")
    paths = Propshaft::LoadPath.new([ elsewhere ], compilers: EngineTest::Application.assets.load_path.compilers)

    assert paths.find("tailwind/keep.css")
  ensure
    FileUtils.rm_rf(elsewhere)
  end

  # TailwindStubFilter.install is the seam of the recorded ruby-gem-conventions R4 exception: the initializer calls it with
  # `config.chadcn.hide_tailwind_stubs`, and it prepends nothing unless the private one-argument hook is really there.
  # Installing on a fake target touches no shared state: the real Propshaft::LoadPath keeps the filter the engine installed.
  def test_install_is_a_no_op_when_disabled
    target = fake_target
    warnings = StringIO.new

    assert_equal :disabled, install_on(target, enabled: false, logger: Logger.new(warnings))
    refute_includes target.ancestors, tailwind_stub_filter
    assert_empty warnings.string
  end

  def test_install_warns_once_naming_the_switch_and_the_fallback_for_a_target_without_the_hook
    target = fake_target(:none)
    warnings = StringIO.new

    assert_equal :unsupported, install_on(target, logger: Logger.new(warnings))
    refute_includes target.ancestors, tailwind_stub_filter
    assert_equal 1, warnings.string.lines.size
    assert_match "hide_tailwind_stubs = false", warnings.string
    assert_match 'Link "tailwind"', warnings.string
  end

  def test_install_warns_and_skips_a_hook_with_another_arity
    target = fake_target(:two_arguments)
    warnings = StringIO.new

    assert_equal :unsupported, install_on(target, logger: Logger.new(warnings))
    refute_includes target.ancestors, tailwind_stub_filter
    assert_match "hide_tailwind_stubs = false", warnings.string
  end

  def test_install_warns_and_skips_a_public_hook
    target = fake_target(:public_one_argument)
    warnings = StringIO.new

    assert_equal :unsupported, install_on(target, logger: Logger.new(warnings))
    refute_includes target.ancestors, tailwind_stub_filter
    assert_match "hide_tailwind_stubs = false", warnings.string
  end

  def test_install_prepends_once
    target = fake_target

    assert_equal :installed, install_on(target)
    assert_equal :installed, install_on(target)
    assert_equal 1, target.ancestors.count(tailwind_stub_filter)
  end

  def test_an_installed_target_hides_only_the_files_under_the_stubs_directory
    target = fake_target
    install_on(target)
    stub = BUILDS.join("tailwind/chadcn.css").to_s
    compiled = BUILDS.join("tailwind.css").to_s
    sibling = BUILDS.join("tailwindx/a.css").to_s

    assert_equal [ compiled, sibling ], target.new.send(:without_dotfiles, [ stub, compiled, sibling ])
  end

  def test_an_installed_target_still_runs_its_own_filter
    target = fake_target
    install_on(target)
    compiled = BUILDS.join("tailwind.css").to_s

    assert_equal [ compiled ], target.new.send(:without_dotfiles, [ compiled, BUILDS.join(".keep").to_s ])
  end

  private

  def tailwind_stub_filter = Chadcn::Engine.const_get(:TailwindStubFilter)

  def install_on(target, enabled: true, logger: Logger.new(IO::NULL))
    tailwind_stub_filter.install(target, stubs_dir: BUILDS.join("tailwind"), enabled: enabled, logger: logger)
  end

  # A stand-in for Propshaft::LoadPath. `:one_argument` has the private one-argument filter (which, like Propshaft's, drops
  # dotfiles), `:public_one_argument` the same filter but public, `:two_arguments` a filter with another signature, `:none` no
  # filter at all.
  def fake_target(hook = :one_argument)
    Class.new.tap do |target|
      case hook
      when :one_argument, :public_one_argument
        target.define_method(:without_dotfiles) { |files| files.reject { |file| File.basename(file).start_with?(".") } }
      when :two_arguments
        target.define_method(:without_dotfiles) { |files, more| files + more }
      end
      target.class_eval { private :without_dotfiles } if %i[one_argument two_arguments].include?(hook)
    end
  end
end
