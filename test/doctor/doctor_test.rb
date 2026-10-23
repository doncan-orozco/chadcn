# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"

# The doctor against fixture apps built in a temp directory: a healthy one and broken variants. No Rails is loaded.
class DoctorTest < Minitest::Test
  Doctor = Chadcn::Doctor
  GEM_ROOT = Chadcn.root

  GEMS = {
    "tailwindcss-rails" => "4.6.0", "tailwindcss-ruby" => "4.3.3", "importmap-rails" => "2.2.3", "stimulus-rails" => "1.3.4",
    "propshaft" => "1.3.0", "phlex" => "2.4.1", "phlex-rails" => "2.4.0"
  }.transform_values { |version| Gem::Version.new(version) }.freeze

  # The block `rails g chadcn:install` writes: the same on every machine (the engine bundle carries the @source for the gem's Ruby files).
  CSS = <<~CSS
    @import "tailwindcss";
    /* chadcn:start (managed by rails g chadcn:install) */
    @import "../builds/tailwind/chadcn";
    @import "./theme/theme.css";
    /* chadcn:end */
  CSS

  def setup = @root = Pathname.new(Dir.mktmpdir("chadcn-doctor"))

  def teardown = FileUtils.remove_entry(@root)

  def write(relative, text)
    path = @root.join(relative)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, text)
  end

  def build_healthy_app
    write("app/assets/tailwind/application.css", CSS)
    write("app/assets/builds/tailwind/chadcn.css", "/* built */")
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
    assert_check run, "source block", :fail, "chadcn:install"
    assert_check run, "engine bundle", :fail, "chadcn:install"
    assert_check run, "theme import", :fail, "chadcn:install"
  end

  # A block written by a generator before the @source line was dropped: Tailwind still styles the app through the engine bundle, the
  # stale path only goes away on the next generator run.
  def test_a_block_that_still_carries_an_at_source_line_warns
    build_healthy_app
    start = "/* chadcn:start (managed by rails g chadcn:install) */\n"
    write("app/assets/tailwind/application.css", CSS.sub(start, %(#{start}@source "../../../nowhere/lib";\n)))
    run = report

    assert_predicate run, :ok?
    assert_check run, "source block", :warn, "chadcn:install"
    assert_includes result(run, "source block").message, "@source"
  end

  def test_tailwind_3_fails
    build_healthy_app
    run = report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("3.3.0"), "tailwindcss-ruby" => Gem::Version.new("3.4.17")))

    assert_check run, "tailwind", :fail, "tailwindcss-rails (4.3.0 or newer)"
  end

  def test_a_tailwind_rails_without_engine_bundling_fails
    build_healthy_app
    # tailwindcss-rails 4.2.3 has no tailwindcss:engines task (added in 4.3.0), so the gem's engine CSS would never be bundled.
    run = report(gems: GEMS.merge("tailwindcss-rails" => Gem::Version.new("4.2.3")))

    assert_check run, "tailwind", :fail, "bundle update tailwindcss-rails (4.3.0 or newer), then bin/rails tailwindcss:build"
    assert_equal "4.3.0", Chadcn::Doctor::Checks::Tailwind::MINIMUM_ENGINE_SUPPORT.to_s
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
    assert_includes Chadcn::Doctor::Report::USAGE, "chadcn:doctor[text|json]"
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

    assert_check report, "theme files", :fail, "chadcn:install"
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

  def test_a_block_without_the_engine_bundle_import_fails_the_source_block_check
    build_healthy_app
    write("app/assets/tailwind/application.css",
          %(@import "tailwindcss";\n/* chadcn:start (managed by rails g chadcn:install) */\n@import "./theme/theme.css";\n/* chadcn:end */\n))
    run = report

    assert_check run, "source block", :fail, "chadcn:install"
    assert_includes result(run, "source block").message, "engine bundle"
  end

  def test_a_block_with_only_the_engine_bundle_import_passes_the_source_block_check
    build_healthy_app
    write("app/assets/tailwind/application.css",
          %(@import "tailwindcss";\n/* chadcn:start (managed by rails g chadcn:install) */\n@import "../builds/tailwind/chadcn";\n/* chadcn:end */\n))
    run = report

    assert_check run, "source block", :pass
    assert_includes result(run, "source block").message, "@source"
    assert_check run, "theme import", :fail, "chadcn:install"
  end

  def test_a_block_that_imports_neither_the_bundle_nor_the_theme_fails
    build_healthy_app
    write("app/assets/tailwind/application.css", CSS.gsub(/^@import "\.[^\n]*\n/, ""))
    run = report

    assert_check run, "source block", :fail, "chadcn:install"
    assert_check run, "engine bundle", :fail, "chadcn:install"
    assert_check run, "theme import", :fail, "chadcn:install"
  end

  def test_theme_css_missing_from_an_existing_directory_fails
    build_healthy_app
    FileUtils.rm_f(@root.join("app/assets/tailwind/theme/theme.css"))

    assert_check report, "theme files", :fail, "chadcn:install"
  end

  def test_missing_phlex_fails_and_phlex_without_phlex_rails_passes
    build_healthy_app

    assert_check report(gems: GEMS.except("phlex")), "phlex versions", :fail, "bundle add phlex"
    assert_check report(gems: GEMS.except("phlex-rails")), "phlex versions", :pass
  end

  def test_a_check_that_raises_is_a_failed_result_and_the_others_still_run
    build_healthy_app
    write("app/assets/tailwind/application.css", "@import \"tailwindcss\";\n/* chadcn:start (managed by rails g chadcn:install) */\n\xFF\xFE\n/* chadcn:end */\n".b)
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

    assert_check run, "tailwind", :fail, "tailwindcss-rails (4.3.0 or newer)"
  end

  def test_a_tailwind_3_binary_under_an_engine_capable_tailwind_rails_fails
    build_healthy_app
    run = report(gems: GEMS.merge("tailwindcss-ruby" => Gem::Version.new("3.4.17")))

    assert_check run, "tailwind", :fail, "tailwindcss-rails (4.3.0 or newer)"
  end

  # The docs state the minimum tailwindcss-rails; they must follow the constant the doctor enforces.
  def test_the_docs_state_the_tailwind_minimum_the_doctor_enforces
    minimum = Doctor::Checks::Tailwind::MINIMUM_ENGINE_SUPPORT.to_s

    %w[README.md docs/compatibility.md].each do |doc|
      assert_includes GEM_ROOT.join(doc).read, "`tailwindcss-rails` #{minimum} or newer", "#{doc} must mention the tailwindcss-rails minimum #{minimum} (Doctor::Checks::Tailwind::MINIMUM_ENGINE_SUPPORT)"
    end
  end

  def test_the_default_phlex_requirement_is_the_gemspecs
    spec = Gem::Specification.load(GEM_ROOT.join("chadcn.gemspec").to_s)
    declared = spec.dependencies.find { |dep| dep.name == "phlex" }.requirement

    assert_equal declared, Gem::Requirement.new(Doctor::Context::DEFAULT_PHLEX_REQUIREMENT)
  end

  def test_the_text_report_lists_a_fix_under_each_failure_and_a_summary
    build_healthy_app
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\n))
    text = report.to_text

    assert_includes text, "[FAIL] source block"
    assert_includes text, "       fix: bin/rails g chadcn:install"
    assert_match(/\d+ passed, \d+ warnings, \d+ failed\z/, text)
  end

  def test_a_clean_text_report_ends_with_the_success_line_after_the_summary
    build_healthy_app
    lines = report.to_text.lines.map(&:chomp)

    assert_match(/\A\d+ passed, 0 warnings, 0 failed\z/, lines[-2])
    assert_equal "All checks passed. You're in peak condition.", lines[-1]
  end

  def test_a_report_with_a_warning_keeps_the_neutral_text_and_has_no_success_line
    text = Doctor::Report.new([ Doctor::Result.passed("a", "ok"), Doctor::Result.warning("b", "odd", fix: "look") ]).to_text

    assert_equal "[PASS] a: ok\n[WARN] b: odd\n       fix: look\n\n1 passed, 1 warnings, 0 failed", text
  end

  def test_a_report_with_a_failure_keeps_the_neutral_text_and_has_no_success_line
    text = Doctor::Report.new([ Doctor::Result.failure("a", "broken", fix: "repair") ]).to_text

    assert_equal "[FAIL] a: broken\n       fix: repair\n\n0 passed, 0 warnings, 1 failed", text
  end

  def test_the_json_report_never_carries_the_success_line
    build_healthy_app

    refute_includes report.to_json, "peak condition"
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
    css = CSS.sub("chadcn\";", "chadcn.css\";").sub("theme.css", "theme")
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
    script = 'require "chadcn"; Chadcn::Doctor.check_classes; abort "Rails loaded" if defined?(Rails)'
    _out, err, status = Open3.capture3(RbConfig.ruby, "-I", GEM_ROOT.join("lib").to_s, "-e", script)

    assert_predicate status, :success?, err
  end
end
