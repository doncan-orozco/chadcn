# frozen_string_literal: true

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
    File.write(BUILDS.join("tailwind/phlex-shadcn.css"), %(@import "/abs/engine.css";))
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
    assert(Propshaft::LoadPath.ancestors.any? { |mod| mod.name == "Phlex::Shadcn::Engine::TailwindStubFilter" })
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
    assert_nil load_path.find("tailwind/phlex-shadcn.css")
    assert_nil load_path.find("tailwind/other-engine.css")
    refute_includes load_path.assets.map { |asset| asset.logical_path.to_s }, "tailwind/phlex-shadcn.css"
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
end
