# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "engine_helper"

# Sprockets support (dev/decisions/sprockets.md): the engine declares its JavaScript precompiled, boots without Propshaft's
# options, and the doctor names the pipeline. The in-process application uses Propshaft; a Sprockets app is proven by
# `bin/smoke --app --assets sprockets`, so here Sprockets' options object is imitated.
class EngineTest::SprocketsSupport < Minitest::Test
  Context = Phlex::Shadcn::Doctor::Context
  Check = Phlex::Shadcn::Doctor::Checks::AssetPipeline
  MANIFEST = "app/assets/config/manifest.js"
  Options = Struct.new(:precompile)
  ENGINE = Phlex::Shadcn::Engine

  def setup = @root = Pathname.new(Dir.mktmpdir("phlex-shadcn-sprockets"))

  def teardown = FileUtils.remove_entry(@root)

  def sprockets = ENGINE.const_get(:SprocketsAssets)

  def engine_directories = %w[app/javascript vendor/javascript].map { |dir| ENGINE.root.join(dir) }

  def context(gems = {}, manifest: nil)
    if manifest
      FileUtils.mkdir_p(@root.join(MANIFEST).dirname)
      File.write(@root.join(MANIFEST), manifest)
    end
    Context.new(root: @root, gems: gems.transform_values { |version| Gem::Version.new(version) })
  end

  def test_the_gems_controllers_primitives_and_vendored_files_are_declared
    paths = sprockets.logical_paths(engine_directories)

    assert_includes paths, "controllers/shadcn/dialog_controller.js"
    assert_includes paths, "shadcn/primitives/presence.js"
    assert_includes paths, "@floating-ui--dom.js"
    assert_equal paths.sort, paths
  end

  def test_every_importmap_pin_of_the_gem_is_declared
    declared = sprockets.logical_paths(engine_directories)
    importmap = File.read(ENGINE.root.join("config/importmap.rb"))
    pinned = importmap.scan(/to: "([^"]+)"/).flatten
    importmap.scan(%r{pin_all_from File.expand_path\("\.\./([^"]+)", __dir__\), under: "([^"]+)"}).each do |dir, under|
      pinned.concat(Dir.glob("**/*.js", base: ENGINE.root.join(dir).to_s).map { |file| "#{under}/#{file}" })
    end

    assert_operator pinned.size, :>, 40
    assert_empty pinned - declared
  end

  def test_install_appends_once_to_a_sprockets_precompile_list
    options = Options.new([ "manifest.js" ])

    assert_equal :declared, sprockets.install(options, directories: engine_directories)
    size = options.precompile.size

    assert_includes options.precompile, "controllers/shadcn/dialog_controller.js"
    assert_equal :declared, sprockets.install(options, directories: engine_directories)
    assert_equal size, options.precompile.size
  end

  def test_install_leaves_propshaft_options_alone
    assert_equal :skipped, sprockets.install(Options.new(nil), directories: engine_directories)
    assert_equal :skipped, sprockets.install(Object.new, directories: engine_directories)
    assert_equal :skipped, sprockets.install(ActiveSupport::OrderedOptions.new, directories: engine_directories)
  end

  # Sprockets' `config.assets` is an options object without excluded_paths: reading it answers nil, and the initializer used to crash on it.
  def test_the_tailwind_input_exclusion_is_skipped_without_excluded_paths
    app = Struct.new(:config).new(Struct.new(:assets).new(ActiveSupport::OrderedOptions.new))
    initializer = ENGINE.initializers.find { |candidate| candidate.name == "phlex_shadcn.exclude_tailwind_inputs" }

    initializer.bind(ENGINE.instance).run(app)

    assert_nil app.config.assets.excluded_paths
  end

  def test_the_doctor_names_propshaft
    result = Check.call(context({ "propshaft" => "1.3.0" }))

    assert_equal :pass, result.status
    assert_includes result.message, "Propshaft 1.3.0"
  end

  def test_the_doctor_names_sprockets_and_accepts_a_manifest_linking_the_builds
    result = Check.call(context({ "sprockets-rails" => "3.5.2", "sprockets" => "4.4.1" }, manifest: "//= link_tree ../images\n//= link_tree ../builds\n"))

    assert_equal :pass, result.status
    assert_includes result.message, "Sprockets 4.4.1 (sprockets-rails 3.5.2)"
  end

  def test_the_doctor_accepts_a_manifest_that_links_the_tailwind_css_directly
    assert_equal :pass, Check.call(context({ "sprockets-rails" => "3.5.2", "sprockets" => "4.4.1" }, manifest: "//= link tailwind.css\n")).status
  end

  def test_the_doctor_accepts_a_css_filtered_builds_tree_and_rejects_a_link_of_the_directory
    gems = { "sprockets-rails" => "3.5.2", "sprockets" => "4.4.1" }

    assert_equal :pass, Check.call(context(gems, manifest: "//= link_tree ../builds .css\n")).status
    assert_equal :warn, Check.call(context(gems, manifest: "//= link ../builds\n")).status
  end

  def test_the_doctor_warns_about_a_sprockets_manifest_without_the_builds
    result = Check.call(context({ "sprockets-rails" => "3.5.2", "sprockets" => "4.4.1" }, manifest: "//= link_tree ../images\n"))

    assert_equal :warn, result.status
    assert_includes result.fix, "link_tree ../builds"
  end

  def test_the_doctor_warns_that_sprockets_3_is_unsupported
    result = Check.call(context({ "sprockets-rails" => "3.4.2", "sprockets" => "3.7.2" }))

    assert_equal :warn, result.status
    assert_includes result.message, "Sprockets below 4 is not supported"
  end

  def test_the_doctor_warns_about_a_missing_sprockets_manifest
    result = Check.call(context({ "sprockets-rails" => "3.5.2", "sprockets" => "4.4.1" }))

    assert_equal :warn, result.status
    assert_includes result.message, "not found"
  end

  def test_the_doctor_warns_about_two_pipelines_and_about_none
    both = Check.call(context({ "propshaft" => "1.3.0", "sprockets-rails" => "3.5.2" }))
    none = Check.call(context)

    assert_equal :warn, both.status
    assert_includes both.message, "both"
    assert_equal :warn, none.status
    assert_includes none.message, "neither"
  end
end
