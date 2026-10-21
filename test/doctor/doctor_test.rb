# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"

# The doctor against fixture apps built in a temp directory: a healthy one and broken variants. No Rails is loaded.
class DoctorTest < Minitest::Test
  Doctor = Phlex::Shadcn::Doctor
  GEM_ROOT = Phlex::Shadcn.root

  GEMS = {
    "tailwindcss-rails" => "4.6.0", "tailwindcss-ruby" => "4.3.3", "importmap-rails" => "2.2.3", "stimulus-rails" => "1.3.4",
    "propshaft" => "1.3.0", "phlex" => "2.4.1", "phlex-rails" => "2.4.0"
  }.transform_values { |version| Gem::Version.new(version) }.freeze

  CSS = <<~CSS
    @import "tailwindcss";
    /* phlex-shadcn:start (managed by rails g phlex:shadcn:install) */
    @source "%<source>s";
    @import "../builds/tailwind/phlex-shadcn";
    @import "./theme/theme.css";
    /* phlex-shadcn:end */
  CSS

  def setup = @root = Pathname.new(Dir.mktmpdir("phlex-shadcn-doctor"))

  def teardown = FileUtils.remove_entry(@root)

  def write(relative, text)
    path = @root.join(relative)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, text)
  end

  def build_healthy_app
    write("app/assets/tailwind/application.css", format(CSS, source: GEM_ROOT.join("lib")))
    write("app/assets/builds/tailwind/phlex-shadcn.css", "/* built */")
    write("app/assets/tailwind/theme/theme.css", "/* theme */")
    FileUtils.mkdir_p(@root.join("app/assets/tailwind/theme/presets"))
    write("config/importmap.rb", %(pin "application"))
    write("app/javascript/controllers/index.js", %(eagerLoadControllersFrom("controllers", application)))
  end

  def report(**overrides)
    options = { root: @root, theme_dir: "app/assets/tailwind/theme", gems: GEMS, phlex_requirement: "~> 2.3" }.merge(overrides)
    Doctor.run(Doctor::Context.new(**options))
  end

  def result(report, name) = report.results.find { |entry| entry.name == name }

  def assert_check(report, name, status, fix_includes = nil)
    found = result(report, name)

    assert found, "no check named #{name.inspect}: #{report.results.map(&:name).inspect}"
    assert_equal status, found.status, "#{name}: #{found.message}"
    assert_includes found.fix, fix_includes if fix_includes
  end

  def test_a_healthy_app_passes_every_check
    build_healthy_app
    run = report

    assert_predicate run, :ok?
    assert_equal [ :pass ], run.results.map(&:status).uniq, run.to_text
    assert_equal Doctor.check_classes.size, run.results.size
  end

  def test_a_missing_source_block_fails_with_the_installer_as_the_fix
    build_healthy_app
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\n))
    run = report

    refute_predicate run, :ok?
    assert_check run, "source block", :fail, "phlex:shadcn:install"
    assert_check run, "engine bundle", :fail, "phlex:shadcn:install"
    assert_check run, "theme import", :fail, "phlex:shadcn:install"
  end

  def test_a_source_line_that_does_not_reach_the_gem_warns
    build_healthy_app
    write("app/assets/tailwind/application.css", format(CSS, source: "../../../nowhere"))

    assert_check report, "source block", :warn, "phlex:shadcn:install"
  end

  def test_tailwind_3_fails
    build_healthy_app
    run = report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("3.3.0"), "tailwindcss-ruby" => Gem::Version.new("3.4.17")))

    assert_check run, "tailwind", :fail, "tailwindcss-rails (4.x)"
  end

  def test_a_tailwind_rails_without_engine_bundling_fails
    build_healthy_app
    # tailwindcss-rails 4.2.3 has no tailwindcss:engines task (added in 4.3.0), so the gem's engine CSS would never be bundled.
    run = report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("4.2.3")))

    assert_check run, "tailwind", :fail, "4.3.0 or newer"
    assert_equal "4.3.0", Phlex::Shadcn::Doctor::Checks::Tailwind::MINIMUM_ENGINE_SUPPORT.to_s
  end

  def test_the_first_tailwind_rails_with_engine_bundling_passes
    build_healthy_app

    assert_check report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("4.3.0"))), "tailwind", :pass
  end

  def test_the_stimulus_fix_names_the_first_registration_file
    build_healthy_app
    write("app/javascript/controllers/index.js", "// nothing registered\n")

    assert_check report, "stimulus controllers", :fail, "to app/javascript/controllers/index.js"
  end

  def test_the_usage_lists_every_format
    assert_includes Phlex::Shadcn::Doctor::Report::USAGE, "phlex_shadcn:doctor[text|json]"
  end

  def test_a_tailwind_3_entry_file_fails
    build_healthy_app
    write("app/assets/tailwind/application.css", "@tailwind base;\n")

    assert_check report, "tailwind", :fail, "@import"
  end

  def test_a_missing_tailwind_gem_fails
    build_healthy_app

    assert_check report(gems: GEMS.except("tailwindcss-rails")), "tailwind", :fail, "tailwindcss-rails"
  end

  def test_a_missing_theme_directory_fails
    build_healthy_app
    FileUtils.rm_rf(@root.join("app/assets/tailwind/theme"))

    assert_check report, "theme files", :fail, "phlex:shadcn:install"
  end

  def test_no_configured_theme_directory_fails
    build_healthy_app
    run = report(theme_dir: nil)

    assert_check run, "theme files", :fail, "theme_dir"
    assert_check run, "theme import", :fail, "theme_dir"
  end

  def test_missing_presets_warn
    build_healthy_app
    FileUtils.rm_rf(@root.join("app/assets/tailwind/theme/presets"))

    assert_check report, "theme files", :warn
  end

  def test_an_unbuilt_engine_bundle_warns_without_failing
    build_healthy_app
    FileUtils.rm_rf(@root.join("app/assets/builds"))
    run = report

    assert_predicate run, :ok?
    assert_check run, "engine bundle", :warn, "tailwindcss:build"
  end

  def test_controllers_that_are_not_registered_fail
    build_healthy_app
    write("app/javascript/controllers/index.js", "// nothing registered\n")

    assert_check report, "stimulus controllers", :fail, "eagerLoadControllersFrom"
  end

  def test_lazy_loaded_controllers_pass
    build_healthy_app
    write("app/javascript/controllers/index.js",
          %(import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"\nlazyLoadControllersFrom("controllers", application)))

    assert_check report, "stimulus controllers", :pass
  end

  def test_commented_out_registrations_do_not_count
    build_healthy_app
    write("app/javascript/controllers/index.js", <<~JS)
      // eagerLoadControllersFrom("controllers", application)
      /* lazyLoadControllersFrom("controllers", application) */
      /*
        eagerLoadControllersFrom("controllers", application)
      */
    JS

    assert_check report, "stimulus controllers", :fail, "eagerLoadControllersFrom"
  end

  def test_a_registration_after_a_trailing_comment_still_counts
    build_healthy_app
    write("app/javascript/controllers/index.js", %(import "x" // setup\neagerLoadControllersFrom("controllers", application)\n))

    assert_check report, "stimulus controllers", :pass
  end

  def test_missing_stimulus_rails_fails
    build_healthy_app

    assert_check report(gems: GEMS.except("stimulus-rails")), "stimulus controllers", :fail, "stimulus:install"
  end

  def test_a_missing_entry_file_fails_the_source_block_and_tailwind
    build_healthy_app
    FileUtils.rm_f(@root.join("app/assets/tailwind/application.css"))
    run = report

    assert_check run, "source block", :fail, "tailwindcss:install"
    assert_check run, "tailwind", :fail, "tailwindcss:install"
  end

  def test_a_block_without_a_source_line_fails
    build_healthy_app
    write("app/assets/tailwind/application.css",
          %(@import "tailwindcss";\n/* phlex-shadcn:start (managed by rails g phlex:shadcn:install) */\n@import "../builds/tailwind/phlex-shadcn";\n/* phlex-shadcn:end */\n))

    assert_check report, "source block", :fail, "phlex:shadcn:install"
    assert_includes result(report, "source block").message, "no @source line"
  end

  def test_a_block_that_imports_neither_the_bundle_nor_the_theme_fails
    build_healthy_app
    write("app/assets/tailwind/application.css", format(CSS, source: GEM_ROOT.join("lib")).gsub(/^@import "\.[^\n]*\n/, ""))
    run = report

    assert_check run, "engine bundle", :fail, "phlex:shadcn:install"
    assert_check run, "theme import", :fail, "phlex:shadcn:install"
  end

  def test_theme_css_missing_from_an_existing_directory_fails
    build_healthy_app
    FileUtils.rm_f(@root.join("app/assets/tailwind/theme/theme.css"))

    assert_check report, "theme files", :fail, "phlex:shadcn:install"
  end

  def test_missing_phlex_fails_and_phlex_without_phlex_rails_passes
    build_healthy_app

    assert_check report(gems: GEMS.except("phlex")), "phlex versions", :fail, "bundle add phlex"
    assert_check report(gems: GEMS.except("phlex-rails")), "phlex versions", :pass
  end

  def test_a_check_that_raises_is_a_failed_result_and_the_others_still_run
    build_healthy_app
    write("app/assets/tailwind/application.css", "@import \"tailwindcss\";\n/* phlex-shadcn:start (managed by rails g phlex:shadcn:install) */\n\xFF\xFE\n/* phlex-shadcn:end */\n".b)
    run = report
    crashed = result(run, "tailwind")

    assert_equal :fail, crashed.status
    assert_includes crashed.message, "InvalidByteSequenceError"
    assert_includes crashed.fix, "readable UTF-8"
    assert_equal Doctor.check_classes.size, run.results.size
    assert_check run, "javascript pipeline", :pass
  end

  def test_a_non_utf8_stimulus_file_asks_for_readable_files_not_a_bug_report
    build_healthy_app
    write("app/javascript/controllers/index.js", "\xFF\xFE eagerLoadControllersFrom(\"controllers\", application)".b)
    crashed = result(report, "stimulus controllers")

    assert_equal :fail, crashed.status
    assert_includes crashed.fix, "readable UTF-8"
  end

  def test_tailwindcss_rails_3_with_a_tailwind_4_binary_fails
    build_healthy_app
    run = report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("3.3.0"), "tailwindcss-ruby" => Gem::Version.new("4.1.0")))

    assert_check run, "tailwind", :fail, "tailwindcss-rails (4.x)"
  end

  def test_the_default_phlex_requirement_is_the_gemspecs
    spec = Gem::Specification.load(GEM_ROOT.join("phlex-shadcn.gemspec").to_s)
    declared = spec.dependencies.find { |dep| dep.name == "phlex" }.requirement

    assert_equal declared, Gem::Requirement.new(Doctor::Context::DEFAULT_PHLEX_REQUIREMENT)
  end

  def test_the_text_report_lists_a_fix_under_each_failure_and_a_summary
    build_healthy_app
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\n))
    text = report.to_text

    assert_includes text, "[FAIL] source block"
    assert_includes text, "       fix: bin/rails g phlex:shadcn:install"
    assert_match(/\d+ passed, \d+ warnings, \d+ failed\z/, text)
  end

  def test_the_javascript_pipeline_is_checked
    build_healthy_app
    FileUtils.rm_f(@root.join("config/importmap.rb"))

    assert_check report, "javascript pipeline", :fail, "importmap:install"

    write("package.json", "{}")

    assert_check report, "javascript pipeline", :warn
  end

  def test_disabled_stub_hiding_warns_and_is_not_applicable_without_propshaft
    build_healthy_app

    assert_check report(hide_tailwind_stubs: false), "propshaft stub filter", :warn, "hide_tailwind_stubs"
    assert_check report(hide_tailwind_stubs: false, gems: GEMS.except("propshaft")), "propshaft stub filter", :pass
  end

  def test_an_enabled_filter_warns_when_propshaft_lacks_the_hook
    build_healthy_app

    assert_check report(propshaft_hook: false), "propshaft stub filter", :warn, "link \"tailwind\""
    assert_check report(propshaft_hook: true), "propshaft stub filter", :pass
    assert_check report(hide_tailwind_stubs: false, propshaft_hook: true), "propshaft stub filter", :warn, "hide_tailwind_stubs"
  end

  def test_the_hook_is_inferred_from_the_propshaft_version_when_propshaft_is_not_loaded
    build_healthy_app

    assert_check report(gems: GEMS.merge("propshaft" => Gem::Version.new("1.1.0"))), "propshaft stub filter", :warn
    assert_check report(gems: GEMS.merge("propshaft" => Gem::Version.new("1.2.1"))), "propshaft stub filter", :pass
    assert_check report(gems: GEMS.merge("propshaft" => Gem::Version.new("1.4.0"))), "propshaft stub filter", :warn
  end

  def test_a_custom_entry_file_is_checked_and_named_in_the_fix
    build_healthy_app
    FileUtils.mv(@root.join("app/assets/tailwind/application.css"), @root.join("app/assets/tailwind/app.css"))
    css = "app/assets/tailwind/app.css"

    assert_predicate report(css: css), :ok?
    run = report(css: "app/assets/stylesheets/none.css")

    assert_check run, "source block", :fail, "install --css app/assets/stylesheets/none.css"
  end

  def test_imports_with_a_css_suffix_count
    build_healthy_app
    css = format(CSS, source: GEM_ROOT.join("lib")).sub("phlex-shadcn\";", "phlex-shadcn.css\";").sub("theme.css", "theme")
    write("app/assets/tailwind/application.css", css)

    assert_equal [ :pass ], report.results.map(&:status).uniq
  end

  def test_a_result_with_an_unknown_status_is_refused
    assert_raises(ArgumentError) { Doctor::Result.new(name: "x", status: :ok, message: "m") }
  end

  def test_importmap_without_the_gem_fails_with_its_own_message
    build_healthy_app
    run = report(gems: GEMS.except("importmap-rails"))

    assert_check run, "javascript pipeline", :fail, "bundle add importmap-rails"
  end

  def test_the_verbatim_stimulus_rails_index_files_register
    build_healthy_app
    eager = <<~JS
      // This file is auto-generated by ./bin/rails stimulus:manifest:update
      // Run that command whenever you add a new controller or create them with
      // ./bin/rails generate stimulus controllerName

      import { application } from "controllers/application"

      import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
      eagerLoadControllersFrom("controllers", application)
    JS
    write("app/javascript/controllers/index.js", eager)

    assert_check report, "stimulus controllers", :pass

    write("app/javascript/controllers/index.js", eager.gsub("eagerLoad", "lazyLoad"))

    assert_check report, "stimulus controllers", :pass
  end

  def test_a_registration_in_application_js_alone_passes
    build_healthy_app
    FileUtils.rm_f(@root.join("app/javascript/controllers/index.js"))
    write("app/javascript/application.js", %(import "@hotwired/turbo-rails"\neagerLoadControllersFrom("controllers", application)\n))

    assert_check report, "stimulus controllers", :pass
  end

  def test_phlex_outside_the_supported_range_fails
    build_healthy_app
    old = GEMS.merge("phlex" => Gem::Version.new("1.11.0"), "phlex-rails" => Gem::Version.new("1.2.0"))

    assert_check report(gems: old), "phlex versions", :fail, "bundle update phlex"
  end

  def test_a_phlex_rails_major_that_differs_from_phlex_fails
    build_healthy_app

    assert_check report(gems: GEMS.merge("phlex-rails" => Gem::Version.new("3.0.0"))), "phlex versions", :fail, "phlex-rails"
  end

  def test_the_json_report_has_a_status_and_a_fix_per_check
    build_healthy_app
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\n))
    json = JSON.parse(report.to_json)

    refute json["ok"]
    assert_equal json["checks"].size, json["summary"].values.sum
    failing = json["checks"].find { |check| check["name"] == "source block" }

    assert_equal "fail", failing["status"]
    assert failing["fix"]
  end

  def test_a_check_is_one_file_discovered_by_name
    names = Dir[File.join(Doctor::CHECKS_DIR, "*.rb")].map { |path| File.basename(path, ".rb") }

    assert_equal names.size, Doctor.check_classes.size
    assert_equal names.sort, Doctor.check_classes.map { |check| check.name.split("::").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase }.sort
  end

  def test_the_doctor_loads_without_rails
    refute defined?(Rails), "Rails is loaded in the plain suite: this test would prove nothing"
    script = 'require "phlex/shadcn"; Phlex::Shadcn::Doctor.check_classes; abort "Rails loaded" if defined?(Rails)'
    _out, err, status = Open3.capture3(RbConfig.ruby, "-I", GEM_ROOT.join("lib").to_s, "-e", script)

    assert_predicate status, :success?, err
  end
end
