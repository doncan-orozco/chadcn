# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Failing fixtures for the packaging rules of .claude/scripts/gem/gem_check.rb, so they cannot silently stop firing. The script lives at
# the root of the monorepo, so these tests skip when the gem is checked out on its own.
class GemCheckRulesTest < Minitest::Test
  SCRIPT = File.expand_path("../../../../.claude/scripts/gem/gem_check.rb", __dir__)

  GEMSPEC = <<~RUBY
    Gem::Specification.new do |s|
      s.name = "phlex-x"
      s.version = "0.1.0"
      s.summary = "summary"
      s.description = "description"
      s.authors = ["someone"]
      s.licenses = ["MIT"]
      s.homepage = "https://github.com/owner/repo/tree/main/gems/phlex-x"
      s.required_ruby_version = ">= 3.3"
      s.metadata = { "source_code_uri" => s.homepage, "changelog_uri" => "https://github.com/owner/repo/blob/main/gems/phlex-x/CHANGELOG.md" }
      s.files = Dir["lib/**/*", "app/**/*", "docs/*.md", "LICENSE", "THIRD_PARTY_NOTICES.md"]
      s.add_dependency "phlex", ">= 2"
    end
  RUBY

  def setup
    skip "gem_check.rb is not available outside the monorepo" unless File.exist?(SCRIPT)
    @dir = Dir.mktmpdir("gem-check-rules")
    @gem = File.join(@dir, "gems/phlex-x")
    write("phlex-x.gemspec", GEMSPEC)
    write("lib/phlex/x.rb", "module Phlex\n  module X; end\nend\n")
    write("app/javascript/controllers/x/dialog_controller.js", "export default class {}\n")
    write("docs/api.md", "# API\n")
    write("test/test_helper.rb", "require 'minitest/autorun'\n")
    write("LICENSE", "MIT\n")
    write("THIRD_PARTY_NOTICES.md", "none\n")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  def test_a_gem_that_packages_its_docs_is_clean
    assert_equal [], findings
  end

  def test_a_packaged_probe_controller_is_dev_material
    write("app/javascript/controllers/x/_probe_presence_controller.js", "export default class {}\n")

    assert_includes codes, "GEMSPEC_DEV_MATERIAL"
  end

  def test_a_packaged_theme_panel_controller_is_dev_material
    write("app/javascript/controllers/x/theme_panel_controller.js", "export default class {}\n")

    assert_includes codes, "GEMSPEC_DEV_MATERIAL"
  end

  def test_a_malformed_changelog_uri_is_reported
    write("phlex-x.gemspec", GEMSPEC.sub("/blob/main/gems/phlex-x/CHANGELOG.md", "/tree/main/gems/phlex-x/blob/main/CHANGELOG.md"))
    found = findings.find { |f| f["code"] == "GEMSPEC_METADATA" }

    refute_nil found
    assert_match(/changelog_uri/, found["detail"])
  end

  def test_a_metadata_uri_that_does_not_parse_is_reported
    write("phlex-x.gemspec", GEMSPEC.sub('"source_code_uri" => s.homepage', '"source_code_uri" => "not a uri"'))

    assert_includes codes, "GEMSPEC_METADATA"
  end

  def test_an_adjacent_double_ref_changelog_uri_is_reported
    write("phlex-x.gemspec", GEMSPEC.sub("https://github.com/owner/repo/blob/main/gems/phlex-x/CHANGELOG.md", "https://github.com/owner/repo/tree/main/blob/main/CHANGELOG.md"))

    assert_includes codes, "GEMSPEC_METADATA"
  end

  def test_a_bare_repo_source_code_uri_is_well_formed
    write("phlex-x.gemspec", GEMSPEC.sub('"source_code_uri" => s.homepage', '"source_code_uri" => "https://github.com/owner/repo"'))

    assert_equal [], findings
  end

  def test_a_nested_docs_markdown_file_is_development_material
    write("docs/guides/deep.md", "# deep\n")
    write("phlex-x.gemspec", GEMSPEC.sub('"docs/*.md"', '"docs/**/*.md"'))

    assert_includes codes, "GEMSPEC_FILES"
  end

  def test_a_packaged_docs_app_is_still_development_material
    write("docs/app/index.html", "<html></html>\n")
    write("phlex-x.gemspec", GEMSPEC.sub('"docs/*.md"', '"docs/**/*"'))

    assert_includes codes, "GEMSPEC_FILES"
  end

  HOST_PATH = 'DEFAULT_CSS = "app/assets/tailwind/application.css"'
  MARKER = "# gem_check:allow GEM_ESCAPES_ROOT -- the doctor reads the host stylesheet"
  DOCTOR = "lib/phlex/shadcn/doctor/context.rb"

  def test_a_hard_coded_host_path_in_core_code_is_reported
    write("lib/phlex/x/helper.rb", "#{HOST_PATH}\n")

    assert_equal [ [ "lib/phlex/x/helper.rb", 1 ] ], escapes
  end

  def test_a_marked_host_path_in_a_doctor_file_is_allowed
    write(DOCTOR, "#{HOST_PATH} #{MARKER}\n")

    assert_equal [], findings
  end

  def test_the_same_marked_literal_outside_the_doctor_still_fails
    write("lib/phlex/x/helper.rb", "#{HOST_PATH} #{MARKER}\n")

    assert_equal [ [ "lib/phlex/x/helper.rb", 1 ] ], escapes
  end

  def test_an_unmarked_host_path_in_a_doctor_file_still_fails
    write(DOCTOR, "#{HOST_PATH}\n")

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_without_a_reason_does_not_allow_the_path
    write(DOCTOR, "#{HOST_PATH} # gem_check:allow GEM_ESCAPES_ROOT\n")

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_for_another_rule_does_not_allow_the_path
    write(DOCTOR, "#{HOST_PATH} # gem_check:allow GEM_RAILS_REFERENCE -- not this rule\n")

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_on_another_line_does_not_allow_the_path
    write(DOCTOR, "#{MARKER}\n#{HOST_PATH}\n")

    assert_equal [ [ DOCTOR, 2 ] ], escapes
  end

  def test_a_marker_inside_a_string_does_not_allow_the_path
    write(DOCTOR, %(#{HOST_PATH} + "#{MARKER}"\n))

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_at_the_tail_of_a_string_does_not_allow_the_path
    write(DOCTOR, %(#{HOST_PATH} + " #{MARKER}"\n))

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_the_doctor_root_file_is_outside_the_allowlist
    write("lib/phlex/shadcn/doctor.rb", "#{HOST_PATH} #{MARKER}\n")

    assert_equal [ [ "lib/phlex/shadcn/doctor.rb", 1 ] ], escapes
  end

  def test_another_namespace_doctor_is_outside_the_allowlist
    write("lib/phlex/x/doctor/check.rb", "#{HOST_PATH} #{MARKER}\n")

    assert_equal [ [ "lib/phlex/x/doctor/check.rb", 1 ] ], escapes
  end

  def test_a_marker_never_allows_require_relative_leaving_the_gem
    write(DOCTOR, "require_relative \"../../../../../secret\" #{MARKER}\n")

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_generator_files_need_no_marker
    write("lib/generators/x/install/manifest.rb", "#{HOST_PATH}\n")

    assert_equal [], findings
  end

  private

  def write(path, content)
    full = File.join(@gem, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def findings
    out, = Open3.capture2(RbConfig.ruby, SCRIPT, "--gem-dir", @gem, "--host-dir", @dir)
    JSON.parse(out)["findings"]
  end

  def escapes = findings.select { |f| f["code"] == "GEM_ESCAPES_ROOT" }.map { |f| [ f["file"], f["line"] ] }

  def codes = findings.map { |f| f["code"] }
end
