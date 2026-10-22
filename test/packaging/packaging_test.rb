# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"
require "uri"

# Builds the gem and inspects the package itself (not the working tree): a consumer gets what the README links to, and no dev-kit material.
class PackagingTest < Minitest::Test
  GEM_DIR = File.expand_path("../..", __dir__)

  @built = nil

  def self.built
    @built ||= begin
      dir = Dir.mktmpdir("chadcn-package")
      Minitest.after_run { FileUtils.remove_entry(dir) }
      out, status = Open3.capture2e(RbConfig.ruby, "-S", "gem", "build", "chadcn.gemspec", "--output", File.join(dir, "chadcn.gem"), chdir: GEM_DIR)
      raise "gem build failed:\n#{out}" unless status.success?

      package = Gem::Package.new(File.join(dir, "chadcn.gem"))
      { warnings: out, spec: package.spec, files: package.spec.files }
    end
  end

  def built = self.class.built

  def test_gem_build_prints_no_warning
    refute_match(/warning/i, built[:warnings])
  end

  def test_every_docs_link_of_readme_and_changelog_is_in_the_package
    links = %w[README.md CHANGELOG.md].flat_map { |name| File.read(File.join(GEM_DIR, name)).scan(/\]\((?!https?:|#|mailto:)([^)#\s]+)/).flatten }
    targets = links.uniq.select { |target| target.start_with?("docs/") }

    refute_empty targets, "README.md links no docs/ page: the check proves nothing"
    missing = targets.reject { |target| packaged?(target) }

    assert_empty missing, "linked from README.md/CHANGELOG.md but not packaged: #{missing.join(', ')}"
  end

  def test_yardopts_and_the_docs_listed_by_it_are_in_the_package
    assert_includes built[:files], ".yardopts"
    listed = File.read(File.join(GEM_DIR, ".yardopts")).scan(%r{docs/\S+\.md}).uniq

    assert_empty listed - built[:files]
  end

  def test_the_generated_llms_files_and_the_agent_skill_are_packaged
    assert_includes built[:files], "llms.txt"
    assert_includes built[:files], "llms-full.txt"
    assert_includes built[:files], "skills/chadcn/SKILL.md"
  end

  def test_the_agent_skill_has_frontmatter_and_stays_short
    skill = File.read(File.join(GEM_DIR, "skills/chadcn/SKILL.md"))

    assert_match(/\A---\nname: chadcn\ndescription: ".+"\n---\n/, skill)
    assert_operator skill.lines.size, :<=, 60, "SKILL.md must stay short: long reference material lives in llms-full.txt"
  end

  def test_no_dev_only_controller_is_packaged
    leaked = built[:files].grep(%r{(?:\A|/)(?:_probe_[^/]*|theme_panel_controller\.js)\z})

    assert_empty leaked, "dev-only controllers every consumer would pin and register: #{leaked.join(', ')}"
  end

  def test_no_dev_kit_tests_or_dummy_app_is_packaged
    assert_empty built[:files].grep(%r{\A(?:dev|test|tmp)/}), "dev material packaged"
  end

  def test_the_probes_and_the_theme_panel_live_in_the_dummy_app
    controllers = File.join(GEM_DIR, "dev/dummy/app/javascript/controllers/chadcn")

    refute_empty Dir[File.join(controllers, "_probe_*_controller.js")]
    assert_path_exists File.join(controllers, "theme_panel_controller.js")
  end

  def test_changelog_uri_has_the_github_blob_shape
    shape = %r{\Ahttps://github\.com/[\w.-]+/[\w.-]+/blob/[\w.-]+/(?:[\w.-]+/)*CHANGELOG\.md\z}

    assert_match shape, built[:spec].metadata["changelog_uri"]
  end

  def test_homepage_and_metadata_uris_parse_as_https
    [ built[:spec].homepage, built[:spec].metadata["source_code_uri"], built[:spec].metadata["changelog_uri"] ].each do |uri|
      assert_instance_of URI::HTTPS, URI.parse(uri), uri
    end
  end

  private

  # A link to a directory ("docs/") is satisfied by any packaged file below it.
  def packaged?(target)
    return built[:files].include?(target) unless target.end_with?("/")

    built[:files].any? { |packaged_file| packaged_file.start_with?(target) }
  end
end
