# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "fileutils"
require_relative "engine_helper"

# `rake phlex_shadcn:doctor` inside the booted engine test application: exit status and output format.
class EngineTest::DoctorTask < Minitest::Test
  def app = EngineTest::Application

  def run_task(*)
    previous = Rake.application
    Rake.application = Rake::Application.new
    app.load_tasks
    out = StringIO.new
    original = $stdout
    $stdout = out
    status = begin
      Rake::Task["phlex_shadcn:doctor"].invoke(*)
      0
    rescue SystemExit => e
      e.status
    end
    [ status, out.string ]
  ensure
    $stdout = original
    Rake.application = previous
  end

  def test_the_task_is_defined_by_the_engine
    previous = Rake.application
    Rake.application = Rake::Application.new
    app.load_tasks

    assert Rake::Task.task_defined?("phlex_shadcn:doctor")
  ensure
    Rake.application = previous
  end

  def test_the_bare_application_fails_the_doctor_with_a_non_zero_exit
    status, out = run_task

    assert_equal 1, status
    assert_includes out, "[FAIL] source block"
    assert_includes out, "fix:"
  end

  def test_json_output
    status, out = run_task("json")
    json = JSON.parse(out)

    assert_equal 1, status
    refute json["ok"]
    assert_includes json["checks"].map { |check| check["name"] }, "tailwind"
  end

  def test_json_output_from_the_environment_variable
    ENV["JSON"] = "1"
    status, out = run_task

    assert_equal 1, status
    refute JSON.parse(out)["ok"]
  ensure
    ENV.delete("JSON")
  end

  def test_a_report_without_failures_exits_zero
    report = Phlex::Shadcn::Doctor::Report.new([ Phlex::Shadcn::Doctor::Result.passed("x", "ok") ])
    original = Phlex::Shadcn::Doctor.method(:run)
    Phlex::Shadcn::Doctor.define_singleton_method(:run) { |_context| report }
    status, out = run_task

    assert_equal 0, status
    assert_includes out, "1 passed"
  ensure
    Phlex::Shadcn::Doctor.define_singleton_method(:run, original)
  end

  def test_the_css_environment_variable_names_the_entry_file
    ENV["CSS"] = "app/assets/stylesheets/custom.css"
    _status, out = run_task

    assert_includes out, "app/assets/stylesheets/custom.css not found"
    assert_includes out, "--css app/assets/stylesheets/custom.css"
  ensure
    ENV.delete("CSS")
  end

  def test_the_doctor_probe_matches_the_stub_filter_hook
    filter = Phlex::Shadcn::Engine.const_get(:TailwindStubFilter)
    context = Phlex::Shadcn::Doctor::Context.new(root: Rails.root)

    assert_equal filter.send(:hook?, ::Propshaft::LoadPath), context.propshaft_hook?
  end

  # The contract between the installer and the doctor: what the generator writes is what the doctor accepts.
  def doctor_statuses_after_install(css)
    require "generators/phlex/shadcn/install/install_generator"
    Dir.mktmpdir("phlex-shadcn-doctor-roundtrip") do |dir|
      FileUtils.mkdir_p(File.join(dir, File.dirname(css)))
      File.write(File.join(dir, css), "@import \"tailwindcss\";\n")
      args = css == Phlex::Shadcn::Doctor::Context::DEFAULT_CSS ? [] : [ "--css", css ]
      capture_io { Phlex::Shadcn::Generators::InstallGenerator.start([ *args, "--theme-dir", "config/theme" ], destination_root: dir) }
      context = Phlex::Shadcn::Doctor::Context.new(root: dir, css: css, theme_dir: "config/theme")
      Phlex::Shadcn::Doctor.run(context).results.to_h { |result| [ result.name, result.status ] }
    end
  end

  def test_the_doctor_accepts_what_the_generator_writes
    statuses = doctor_statuses_after_install(Phlex::Shadcn::Doctor::Context::DEFAULT_CSS)

    assert_equal :pass, statuses.fetch("source block")
    assert_equal :pass, statuses.fetch("theme import")
    assert_equal :pass, statuses.fetch("theme files")
    assert_equal :warn, statuses.fetch("engine bundle") # imported, but only built by tailwindcss:build
  end

  def test_the_doctor_accepts_what_the_generator_writes_for_a_custom_entry_file
    statuses = doctor_statuses_after_install("app/assets/stylesheets/app.css")

    assert_equal :pass, statuses.fetch("source block")
    assert_equal :pass, statuses.fetch("theme import")
  end

  # The javascript pipeline check, on an app directory with injected gems.
  def js_pipeline(dir, gems = {})
    context = Phlex::Shadcn::Doctor::Context.new(root: dir, gems: gems.transform_values { |version| Gem::Version.new(version) })
    Phlex::Shadcn::Doctor::Checks::JsPipeline.call(context)
  end

  def esbuild_app(dir)
    require "generators/phlex/shadcn/install/install_generator"
    File.write(File.join(dir, "package.json"), %({"scripts": {"build": "esbuild app/javascript/*.*"}, "dependencies": {"@floating-ui/dom": "^1.8.0"}}))
    FileUtils.mkdir_p(File.join(dir, "app/javascript"))
    File.write(File.join(dir, "app/javascript/application.js"), "import \"./controllers\"\n")
  end

  def test_the_pipeline_check_passes_for_importmap
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/importmap.rb"), "")

      assert_equal :pass, js_pipeline(dir, "importmap-rails" => "2.0.0").status
      assert_equal :fail, js_pipeline(dir).status
    end
  end

  def test_the_pipeline_check_fails_for_an_esbuild_app_that_was_never_installed
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      esbuild_app(dir)
      result = js_pipeline(dir)

      assert_equal :fail, result.status
      assert_includes result.message, "esbuild (jsbundling)"
      assert_includes result.message, "copied file(s) missing"
      assert_includes result.fix, "--js esbuild"
    end
  end

  def test_the_pipeline_check_passes_after_the_installer_and_fails_when_a_copy_goes_stale_or_wiring_is_missing
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      esbuild_app(dir)
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      File.write(File.join(dir, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
      capture_io { Phlex::Shadcn::Generators::InstallGenerator.start([], destination_root: dir) }

      assert_equal :pass, js_pipeline(dir).status, js_pipeline(dir).message

      File.write(File.join(dir, "app/javascript/shadcn/primitives/presence.js"), "// edited\n")
      stale = js_pipeline(dir)

      assert_equal :fail, stale.status
      assert_includes stale.message, "differ from the gem's (app/javascript/shadcn/primitives/presence.js)"

      File.write(File.join(dir, "app/javascript/application.js"), "")
      File.write(File.join(dir, "package.json"), %({"scripts": {"build": "esbuild"}}))

      assert_includes js_pipeline(dir).message, "lacks"
    end
  end

  def test_the_pipeline_check_reads_the_entry_import_like_the_generator
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      esbuild_app(dir)
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      File.write(File.join(dir, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
      capture_io { Phlex::Shadcn::Generators::InstallGenerator.start([], destination_root: dir) }
      entry = File.join(dir, "app/javascript/application.js")

      File.write(entry, "import \"./controllers\"\nimport './controllers/shadcn'\n")

      assert_equal :pass, js_pipeline(dir).status, js_pipeline(dir).message

      File.write(entry, "import \"./controllers\"\n// import \"./controllers/shadcn\"\n")

      assert_includes js_pipeline(dir).message, "lacks"
    end
  end

  def test_the_stimulus_check_accepts_the_installers_registration_in_an_esbuild_app
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      esbuild_app(dir)
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      File.write(File.join(dir, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
      capture_io { Phlex::Shadcn::Generators::InstallGenerator.start([], destination_root: dir) }
      context = Phlex::Shadcn::Doctor::Context.new(root: dir, gems: { "stimulus-rails" => Gem::Version.new("1.3.0") })

      assert_equal :pass, Phlex::Shadcn::Doctor::Checks::Stimulus.call(context).status
    end
  end

  def test_the_stimulus_check_does_not_trust_the_esbuild_index_in_an_importmap_app
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/javascript/controllers/shadcn"))
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/importmap.rb"), "")
      File.write(File.join(dir, "app/javascript/controllers/shadcn/index.js"), "")
      context = Phlex::Shadcn::Doctor::Context.new(root: dir, gems: { "stimulus-rails" => Gem::Version.new("1.3.0") })

      assert_equal :fail, Phlex::Shadcn::Doctor::Checks::Stimulus.call(context).status
    end
  end

  def test_the_pipeline_check_warns_for_an_unknown_bundler_and_fails_without_a_pipeline
    Dir.mktmpdir("phlex-shadcn-doctor-js") do |dir|
      assert_equal :fail, js_pipeline(dir).status
      File.write(File.join(dir, "package.json"), %({"scripts": {"build": "webpack"}}))

      assert_equal :warn, js_pipeline(dir).status
    end
  end
end
