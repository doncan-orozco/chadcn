# frozen_string_literal: true

# Characterization of the smoke harness (bin/smoke) and of the CI workflow that runs it. Offline: the clean-app mode is not run here
# (it needs network and a browser), only its inputs are checked.
require "test_helper"
require "yaml"
require "rubygems"
require "tempfile"
require_relative "runner"

class SmokeRunnerTest < Minitest::Test
  GEM_ROOT = Pathname.new(File.expand_path("../..", __dir__))
  # Monorepo: the workflow sits at the repository root; once the gem has its own repository, at the gem root.
  WORKFLOW_CANDIDATES = [ GEM_ROOT.join(".github/workflows/phlex-shadcn.yml"),
                          GEM_ROOT.join("../../.github/workflows/phlex-shadcn.yml") ].freeze

  def readme = Smoke::Readme.new(GEM_ROOT.join("README.md"))

  def workflow
    path = WORKFLOW_CANDIDATES.find(&:file?)
    flunk "no phlex-shadcn.yml at #{WORKFLOW_CANDIDATES.join(' or ')}: the CI config moved, update this test" unless path
    YAML.load_file(path)
  end

  def test_the_readme_install_steps_are_the_ones_the_smoke_replays
    assert_equal [ "bundle install", "bin/rails g phlex:shadcn:install", "bin/rails tailwindcss:build" ], readme.install_commands
    assert_equal "bin/rails g phlex:install", readme.phlex_rails_install_command
    assert_includes readme.gemfile_lines, 'gem "phlex-shadcn"'
    assert_includes readme.gemfile_lines, 'gem "phlex-rails"'
    assert_match(/class Views::Demo::Index < Views::Base/, readme.view_source)
    assert_match(/class DemoController < ApplicationController/, readme.controller_source)
    assert_match(%r{\Arequire "phlex/shadcn"}, readme.without_rails_source)
  end

  def test_the_readme_reader_fails_loudly_when_the_quick_start_is_gone
    Tempfile.create([ "README", ".md" ]) do |file|
      file.write("# phlex-shadcn\n\n```ruby\nputs 1\n```\n")
      file.flush

      error = assert_raises(RuntimeError) { Smoke::Readme.new(file.path).install_commands }
      assert_match(/expected exactly 1/, error.message)
    end
  end

  def test_the_docs_fences_include_the_readme_and_every_guide
    files = Smoke::Docs.new(GEM_ROOT).fences.map { |fence| fence[:file] }.uniq

    assert_includes files, "README.md"
    Dir[GEM_ROOT.join("docs/*.md").to_s].each { |page| assert_includes files, "docs/#{File.basename(page)}" }
  end

  def test_every_known_red_fence_matches_exactly_one_fence
    fences = Smoke::Docs.new(GEM_ROOT).fences

    Smoke::Docs::KNOWN_RED.each do |entry|
      assert_equal 1, fences.count { |fence| fence[:known_red]&.fetch(:reason) == entry[:reason] }, entry[:reason]
    end
  end

  def test_the_plain_smoke_passes_offline_without_rails
    result = Smoke::Plain.new(GEM_ROOT).call

    assert_predicate result, :success?, result.output
    assert_includes result.output, 'data-slot="dialog-trigger"'
  end

  def test_the_workflow_runs_only_for_the_gem
    triggers = workflow["on"] || workflow[true]

    %w[push pull_request].each do |event|
      assert_equal [ "gems/phlex-shadcn/**", ".github/workflows/phlex-shadcn.yml" ], triggers.fetch(event).fetch("paths"), event
    end
  end

  def test_the_matrix_rubies_are_the_ones_the_gemspec_claims
    spec = Gem::Specification.load(GEM_ROOT.join("phlex-shadcn.gemspec").to_s)
    rubies = workflow.dig("jobs", "gem", "strategy", "matrix").fetch("ruby").map(&:to_s)
    floor = spec.required_ruby_version.requirements.find { |operator, _| operator == ">=" }.last.segments.first(2).join(".")

    rubies.each { |ruby| assert spec.required_ruby_version.satisfied_by?(Gem::Version.new(ruby)), "ruby #{ruby}" }
    assert_includes rubies, floor, "the lowest Ruby the gemspec allows is tested"
  end

  def test_the_matrix_phlex_rows_span_the_gemspec_range
    spec = Gem::Specification.load(GEM_ROOT.join("phlex-shadcn.gemspec").to_s)
    requirement = spec.dependencies.find { |dependency| dependency.name == "phlex" }.requirement
    floor = requirement.requirements.first.last
    versions = workflow.dig("jobs", "gem", "strategy", "matrix").fetch("gemfile").map { |gemfile| phlex_version_of(GEM_ROOT.join(gemfile)) }

    versions.each { |version| assert requirement.satisfied_by?(version), "phlex #{version} is outside #{requirement}" }
    assert(versions.any? { |version| version.segments.first(2) == floor.segments.first(2) }, "no matrix row tests phlex #{floor}")
  end

  private

  # The phlex a matrix gemfile resolves: its pin, else its committed lockfile.
  def phlex_version_of(gemfile)
    assert_predicate gemfile, :file?, gemfile.to_s
    pinned = gemfile.read[/gem "phlex", "[~>= ]*([\d.]+)"/, 1]
    return Gem::Version.new(pinned) if pinned

    lock = Pathname.new("#{gemfile}.lock")
    locked = lock.file? && lock.read[/^    phlex \(([\d.]+)\)/, 1]
    flunk "#{gemfile} neither pins phlex nor locks it" unless locked
    Gem::Version.new(locked)
  end
end
