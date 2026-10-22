# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

# The plain suite never loads Rails; the engine and generator tests boot Rails and run with `rake test:engine`.
RAILS_TESTS = "test/{engine,generators}/**/*_test.rb"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude(FileList[RAILS_TESTS])
  t.warning = false
end

namespace :test do
  Rake::TestTask.new(:engine) do |t|
    t.libs << "test" << "lib"
    t.test_files = FileList[RAILS_TESTS]
    t.warning = false
  end

  # The repository tooling (.claude/scripts), not the gem: the audit receipt, the epic board and the gem gate.
  Rake::TestTask.new(:tooling) do |t|
    t.test_files = FileList[".claude/scripts/test/**/*_test.rb"]
    t.warning = false
  end
end

task default: [ :test, "test:engine" ]

namespace :public_api do
  desc "Regenerate test/fixtures/public_api.txt from the current public surface (review the diff, add a CHANGELOG entry)"
  task :update do
    sh({ "PUBLIC_API_UPDATE" => "1", "CI" => nil }, FileUtils::RUBY, "-Itest", "-Ilib", "test/public_api_test.rb",
       "-n", "test_public_surface_matches_the_fixture")
    sh FileUtils::RUBY, "-Itest", "-Ilib", "test/public_api_test.rb"
  end
end

namespace :llms do
  llms_cli = ->(command) { sh FileUtils::RUBY, File.expand_path("dev/llms/cli.rb", __dir__), command }

  desc "Regenerate llms.txt, llms-full.txt and skills/chadcn/SKILL.md from the YARD docs and the Stimulus controllers"
  task(:generate) { llms_cli.call("generate") }

  desc "Fail when the committed llms files differ from what `llms:generate` produces"
  task(:check) { llms_cli.call("check") }
end
