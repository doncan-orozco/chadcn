# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Failing fixtures for the packaging rules of .claude/scripts/gem/gem_check.rb, so they cannot silently stop firing.
class GemCheckRulesTest < Minitest::Test
  SCRIPT = File.expand_path("../../.claude/scripts/gem/gem_check.rb", __dir__)

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
    raise "#{SCRIPT} is missing: the gem gate moved, update this test" unless File.exist?(SCRIPT)

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
  DOCTOR = "lib/chadcn/doctor/context.rb"

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
    write("lib/chadcn/doctor.rb", "#{HOST_PATH} #{MARKER}\n")

    assert_equal [ [ "lib/chadcn/doctor.rb", 1 ] ], escapes
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

  CORE = "lib/phlex/x/helper.rb"

  # --- comments: a commented-out line is not code, in either direction ---------------------------------------------

  def test_a_commented_out_host_path_is_not_a_finding
    write(CORE, "# #{HOST_PATH}\nx = 1\n")

    assert_equal [], findings
  end

  def test_a_commented_out_host_path_in_the_middle_of_a_file_is_not_a_finding
    write(CORE, "a = 1\n#{HOST_PATH.sub('DEFAULT_CSS', '# OLD')}\nb = 2 # app/assets/x is documented here\n")

    assert_equal [], findings
  end

  def test_code_after_a_commented_line_is_still_checked
    write(CORE, "# note\nx = 1 # trailing\n#{HOST_PATH}\n")

    assert_equal [ [ CORE, 3 ] ], escapes
  end

  def test_code_before_a_trailing_comment_is_still_checked
    write(CORE, "#{HOST_PATH} # only a note, not a marker\n")

    assert_equal [ [ CORE, 1 ] ], escapes
  end

  def test_a_hash_inside_a_string_does_not_hide_the_rest_of_the_line
    write(CORE, %(NOTE = "a # b"; #{HOST_PATH}\n))

    assert_equal [ [ CORE, 1 ] ], escapes
  end

  def test_an_embedded_doc_block_is_not_code
    write(CORE, "=begin\n#{HOST_PATH}\n=end\nx = 1\n")

    assert_equal [], findings
  end

  def test_a_commented_out_rails_reference_is_not_a_finding
    write(CORE, "# Rails.root.join('x')\nx = 1\n")

    assert_equal [], findings
  end

  def test_a_rails_reference_after_a_comment_line_is_still_a_finding
    write(CORE, "# note\nRails.root\n")

    assert_includes codes, "GEM_RAILS_REFERENCE"
  end

  def test_a_provenance_mention_in_a_comment_still_requires_a_notice
    write(CORE, "# ported from Radix\nx = 1\n")

    assert_includes codes, "GEM_NOTICES"
  end

  # --- spellings of a host path: each one is the same hard-coded path --------------------------------------------

  SPELLINGS = {
    "a %w list" => "LIST = %w[app/assets/tailwind/application.css]",
    "a %w list with a leading ./" => "LIST = %w[./app/javascript/application.js]",
    "a %w list element among others" => "LIST = %w[lib/x app/views/layouts/application.rb]",
    "%w pieces joined with a slash" => "LIST = %w[app assets tailwind].join(\"/\")",
    "File.join pieces" => "PATH = File.join(\"app\", \"assets\", \"tailwind\", \"application.css\")",
    "File.join with a root first" => "PATH = File.join(root, \"app\", \"javascript\", \"application.js\")",
    "File.join with a bare directory" => "PATH = File.join(root, \"app/assets\")",
    "an interpolated prefix" => "PATH = \"\#{root}/app/assets/tailwind/application.css\"",
    "an interpolated ivar prefix" => "PATH = \"\#@root/app/views/layouts\"",
    "a plus concatenation" => "PATH = \"app/\" + \"assets/tailwind/application.css\"",
    "a split directory name" => "PATH = \"app\" + \"/assets/tailwind\"",
    "a shovel concatenation" => "PATH = +\"app/\" << \"components/x.rb\"",
    "adjacent literals" => "PATH = \"app/\" \"views/layouts\"",
    "a Pathname / operator" => "PATH = Pathname(\"app\") / \"assets\" / \"x.css\"",
    "chained join calls" => "PATH = root.join(\"app\").join(\"javascript\")",
    "a backslash continuation" => "PATH = \"app/\" \\\n  \"components/x.rb\"",
    "a File.join inside an interpolation" => "PATH = \"\#{File.join(root, \"app\", \"assets\")}/x.css\"",
    "a join chain inside an interpolation" => "PATH = \"\#{root.join(\"app\").join(\"views\")}\"",
    "a join chain after a newline" => "P = %w[app assets]\n  .join(\"/\")",
    "a path after a quoted symbol interpolation" => "P = \"\#{h[:'k']}/app\" + \"/assets\"",
    "a require option" => "OPTS = { require: File.join(\"app\", \"views\") }",
    "a multi-line plus concatenation" => "PATH = \"app/\" +\n  \"assets/x.css\""
  }.freeze

  SPELLINGS.each do |name, code|
    define_method(:"test_#{name.gsub(/\W+/, '_')}_is_a_host_path") do
      write(CORE, "#{code}\n")

      assert_equal [ [ CORE, 1 ] ], escapes
    end
  end

  def test_a_multi_line_percent_w_list_reports_the_line_of_each_path
    write(CORE, "FILES = %w[\n  app/javascript/controllers/index.js\n  lib/x.rb\n  app/javascript/application.js\n].freeze\n")

    assert_equal [ [ CORE, 2 ], [ CORE, 4 ] ], escapes
  end

  def test_a_multi_line_path_is_reported_on_the_line_of_its_first_piece
    write(CORE, "PATH = File.join(\n  \"app\",\n  \"assets\"\n)\n")

    assert_equal [ [ CORE, 2 ] ], escapes
  end

  def test_a_require_relative_into_the_gems_own_app_directory_is_not_a_host_path
    write(CORE, "require_relative \"../../../app/components/base\"\n")

    assert_equal [], findings
  end

  def test_a_require_relative_leaving_the_gem_is_one_escape_not_two
    write(CORE, "require_relative \"../../../../app/components/base\"\n")

    assert_equal [ [ CORE, 1 ] ], escapes
  end

  def test_a_marked_doctor_list_with_a_non_host_first_entry_is_clean
    write(DOCTOR, "FILES = [\n  \"config/importmap.rb\",\n  \"app/javascript/application.js\" #{MARKER}\n]\n")

    assert_equal [], findings
  end

  def test_crlf_lines_are_stripped_and_checked
    write(CORE, "# #{HOST_PATH}\r\n#{HOST_PATH}\r\n")

    assert_equal [ [ CORE, 2 ] ], escapes
  end

  def test_a_comment_after_multibyte_text_is_cut_at_the_right_column
    write(CORE, "A = \"ñandú\" # #{HOST_PATH}\nB = \"é\"; #{HOST_PATH}\n")

    assert_equal [ [ CORE, 2 ] ], escapes
  end

  def test_the_data_section_after_end_is_scanned
    write(CORE, "x = 1\n__END__\n#{HOST_PATH}\n")

    assert_equal [ [ CORE, 3 ] ], escapes
  end

  def test_commented_dependencies_are_not_findings
    write(CORE, "# ActiveSupport::Inflector.camelize(x)\n# x.presence\nx = 1\n")

    assert_equal [], findings
  end

  def test_a_heredoc_body_is_not_a_path
    write(CORE, "TEXT = <<~MSG\n  edit app/assets/tailwind/application.css\nMSG\n")

    assert_equal [], findings
  end

  NOT_PATHS = {
    "prose that mentions a path" => "MESSAGE = \"add the import to app/assets/tailwind/application.css\"",
    "an interpolated message" => "MESSAGE = \"\#{name} reads app/javascript/application.js\"",
    "another app directory" => "PATH = File.join(\"app\", \"models\", \"user.rb\")",
    "a name ending in app" => "PATH = \"myapp/assets/x.css\"",
    "a lib path" => "PATH = File.join(\"lib\", \"assets\", \"x.css\")",
    "an unrelated %w list" => "LIST = %w[app lib assets]",
    "pieces that are not joined" => "PAIR = [\"app\", \"x\"] + [\"assets\"]",
    "a regexp" => "PATTERN = %r{app/assets/x}",
    "a quoted array of names" => "DIRS = [\"app\", \"components\"]",
    "two method arguments" => "call(\"app\", \"views\")",
    "a label key next to its value" => "H = { \"app\": \"/assets/x\" }",
    "an interpolated literal next to the outer neighbour" => "P = \"\#{h[\"app/\"]}\" + \"views/x\"",
    "a symbol list" => "NAMES = %i[app assets]"
  }.freeze

  NOT_PATHS.each do |name, code|
    define_method(:"test_#{name.gsub(/\W+/, '_')}_is_not_a_host_path") do
      write(CORE, "#{code}\n")

      assert_equal [], escapes
    end
  end

  # --- the allowlist keeps its meaning for the new spellings -------------------------------------------------------

  def test_a_marked_file_join_in_a_doctor_file_is_allowed
    write(DOCTOR, %(PATH = File.join("app", "assets", "x.css") #{MARKER}\n))

    assert_equal [], findings
  end

  def test_a_marked_percent_w_list_in_a_doctor_file_is_allowed_when_the_marker_trails_its_line
    write(DOCTOR, "LIST = %w[app/assets/x.css] #{MARKER}\n")

    assert_equal [], findings
  end

  def test_a_marked_interpolated_path_in_a_doctor_file_is_allowed
    write(DOCTOR, %(PATH = "\#{root}/app/assets/x.css" #{MARKER}\n))

    assert_equal [], findings
  end

  def test_the_same_marked_file_join_outside_the_doctor_still_fails
    write(CORE, %(PATH = File.join("app", "assets", "x.css") #{MARKER}\n))

    assert_equal [ [ CORE, 1 ] ], escapes
  end

  def test_an_unmarked_file_join_in_a_doctor_file_still_fails
    write(DOCTOR, %(PATH = File.join("app", "assets", "x.css")\n))

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_on_the_second_line_of_a_split_path_does_not_allow_it
    write(DOCTOR, %(PATH = File.join("app",\n  "assets") #{MARKER}\n))

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_a_marker_inside_a_multi_line_percent_w_list_is_only_a_word
    write(DOCTOR, "FILES = %w[\n  app/assets/x.css #{MARKER}\n]\n")

    assert_equal [ [ DOCTOR, 2 ] ], escapes
  end

  def test_a_marker_in_a_string_after_a_file_join_does_not_allow_it
    write(DOCTOR, %(PATH = File.join("app", "assets") + " #{MARKER}"\n))

    assert_equal [ [ DOCTOR, 1 ] ], escapes
  end

  def test_generator_files_need_no_marker_for_any_spelling
    write("lib/generators/x/install/manifest.rb", %(PATH = File.join("app", "assets", "x.css")\nLIST = %w[app/views/x]\n))

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
