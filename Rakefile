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
end

task default: [ :test, "test:engine" ]
