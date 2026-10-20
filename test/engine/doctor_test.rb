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
end
