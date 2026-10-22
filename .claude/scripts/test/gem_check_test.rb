require_relative "test_helper"
require "tmpdir"
require "open3"
require "rbconfig"

# Golden tests for the gem gate (.claude/scripts/gem/gem_check.rb): a clean fixture gem passes and each seeded defect is reported
# with its code, so the gate cannot silently stop catching what the extraction relies on.
class GemCheckTest < ActiveSupport::TestCase
  SCRIPT = TOOLING_ROOT.join(".claude/scripts/gem/gem_check.rb").to_s

  GEMSPEC = <<~RUBY
    Gem::Specification.new do |s|
      s.name = "phlex-x"
      s.version = "0.1.0"
      s.summary = "summary"
      s.description = "description"
      s.authors = ["someone"]
      s.licenses = ["MIT"]
      s.homepage = "https://example.com"
      s.required_ruby_version = ">= 3.3"
      s.metadata = { "source_code_uri" => "https://example.com/src", "changelog_uri" => "https://example.com/changes" }
      s.files = Dir["lib/**/*", "LICENSE", "THIRD_PARTY_NOTICES.md"]
      s.add_dependency "phlex", ">= 2"
      s.add_dependency "tailwind_merge", ">= 1"
    end
  RUBY

  BASE = <<~RUBY
    module Chadcn
      class Base < Phlex::HTML
        def cn(*classes) = TailwindMerge::Merger.new.merge(classes.join(" "))
      end
    end
  RUBY

  setup do
    @dir = Dir.mktmpdir("gem-check")
    @host = File.join(@dir, "host")
    @gem = File.join(@host, "gems/phlex-x")
    write(@host, "app/components/base.rb", "class Components::Base < Phlex::HTML; end\n")
    write(@host, "app/models/article.rb", "class Article < ApplicationRecord; end\n")
    write(@gem, "phlex-x.gemspec", GEMSPEC)
    write(@gem, "lib/chadcn.rb", BASE)
    write(@gem, "lib/chadcn/engine.rb", "module Chadcn\n  class Engine < ::Rails::Engine; end\nend\n")
    write(@gem, "test/test_helper.rb", "require 'minitest/autorun'\n")
    write(@gem, "LICENSE", "MIT\n")
    write(@gem, "THIRD_PARTY_NOTICES.md", "shadcn/ui (MIT), Radix (MIT), Lucide (ISC)\n")
  end

  teardown { FileUtils.remove_entry(@dir) }

  def write(root, path, content)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def check(gem_dir: @gem)
    out, _err, status = Open3.capture3(RbConfig.ruby, SCRIPT, "--gem-dir", gem_dir, "--host-dir", @host)
    result = JSON.parse(out)
    [ result["findings"].map { |f| f["code"] }, status.exitstatus, result ]
  end

  def finding(result, code) = result["findings"].find { |f| f["code"] == code }

  test "a clean gem passes" do
    codes, status, result = check

    assert_equal [], codes, result["findings"].inspect
    assert_equal 0, status
  end

  test "a reference to a constant only the host defines is reported with file and line" do
    write(@gem, "lib/chadcn/leak.rb", "module Chadcn\n  class Leak < Components::Base\n    def x = Article.first\n  end\nend\n")
    codes, status, result = check

    assert_equal 1, status
    assert_equal 2, codes.count("GEM_HOST_CONSTANT")
    assert_equal [ 2, 3 ], result["findings"].select { |f| f["code"] == "GEM_HOST_CONSTANT" }.map { |f| f["line"] }.sort
  end

  test "a constant the gem declares itself is not a host reference even when the host uses the same name" do
    write(@host, "app/models/item.rb", "class Item < ApplicationRecord; end\n")
    write(@gem, "lib/chadcn/item.rb", "module Chadcn\n  class Item < Base; end\nend\nChadcn::Item\nItem.name\n")

    assert_not_includes check[0], "GEM_HOST_CONSTANT"
  end

  test "Rails is allowed in the engine file and rejected in core code" do
    assert_not_includes check[0], "GEM_RAILS_REFERENCE"
    write(@gem, "lib/chadcn/dev.rb", "module Chadcn\n  DEV = Rails.env.development?\nend\n")
    codes, _, result = check

    assert_includes codes, "GEM_RAILS_REFERENCE"
    assert_equal "lib/chadcn/dev.rb", finding(result, "GEM_RAILS_REFERENCE")["file"]
  end

  test "integration files in nested generator and task directories may use Rails and host paths" do
    write(@gem, "lib/generators/chadcn/install/install_generator.rb",
          "class Chadcn::InstallGenerator < Rails::Generators::Base\n  CSS = \"app/assets/tailwind/application.css\"\nend\n")
    write(@gem, "lib/tasks/deep/theme.rake", "namespace :theme do\n  task x: :environment do\n    puts TOOLING_ROOT.join(\"app/assets/x\")\n  end\nend\n")
    codes, = check

    assert_not_includes codes, "GEM_RAILS_REFERENCE"
    assert_not_includes codes, "GEM_ESCAPES_ROOT"
  end

  test "loading the engine only when Rails is present is not a Rails reference" do
    write(@gem, "lib/chadcn/loader.rb", "require \"chadcn/engine\" if defined?(Rails::Engine)\nrequire \"x/railtie\" if defined?( Rails )\n")

    assert_not_includes check[0], "GEM_RAILS_REFERENCE"
  end

  test "a real Rails dependency next to a guard is still reported" do
    write(@gem, "lib/chadcn/mixed.rb", "x = defined?(Rails::Engine)\nRails.logger.info(\"hi\") if defined?(Rails)\n")
    codes, _, result = check

    assert_includes codes, "GEM_RAILS_REFERENCE"
    assert_equal [ 2 ], result["findings"].select { |f| f["code"] == "GEM_RAILS_REFERENCE" }.map { |f| f["line"] }
  end

  test "a library namespace used without its gem declared is reported" do
    write(@gem, "phlex-x.gemspec", GEMSPEC.sub(%(  s.add_dependency "tailwind_merge", ">= 1"\n), ""))
    result = check[2]

    assert_equal "tailwind_merge is used but the gemspec has no runtime dependency on it", finding(result, "GEM_UNDECLARED_DEPENDENCY")["detail"]
  end

  test "ActiveSupport extensions need activesupport declared or required" do
    write(@gem, "lib/chadcn/merge.rb", "module Chadcn\n  def self.m(a, b) = a.deep_merge(b).presence\nend\n")

    assert_includes check[0], "GEM_ACTIVESUPPORT_EXT"
    write(@gem, "phlex-x.gemspec", GEMSPEC.sub(%(  s.add_dependency "phlex", ">= 2"\n), %(  s.add_dependency "phlex", ">= 2"\n  s.add_dependency "activesupport", ">= 7"\n)))

    assert_not_includes check[0], "GEM_ACTIVESUPPORT_EXT"
  end

  test "require_relative may not leave the gem and host paths may not be hard-coded outside the Rails files" do
    write(@gem, "lib/chadcn/up.rb", "require_relative '../../../../app/components/base'\n")
    write(@gem, "lib/chadcn/ok.rb", "require_relative 'engine'\nrequire_relative '../chadcn'\n")
    write(@gem, "lib/chadcn/path.rb", "module Chadcn\n  CSS = 'app/assets/tailwind/theme/theme.css'\nend\n")
    codes, _, result = check
    flagged = result["findings"].select { |f| f["code"] == "GEM_ESCAPES_ROOT" }.map { |f| f["file"] }

    assert_equal 2, codes.count("GEM_ESCAPES_ROOT")
    assert_equal [ "lib/chadcn/path.rb", "lib/chadcn/up.rb" ], flagged.sort
  end

  test "gemspec metadata, ruby version, license and packaged files are checked" do
    write(@gem, "phlex-x.gemspec", GEMSPEC.sub(%(  s.licenses = ["MIT"]\n), "").sub(%(  s.required_ruby_version = ">= 3.3"\n), "")
                                         .sub(%(, "changelog_uri" => "https://example.com/changes"), "").sub(%(Dir["lib/**/*",), %(Dir["lib/**/*", "test/**/*", "dev/**/*",)))
    write(@gem, "dev/oracle.json", "{}")
    result = check[2]
    details = result["findings"].select { |f| f["code"].start_with?("GEMSPEC") }.map { |f| f["detail"] }.join("\n")

    assert_includes details, "license is missing"
    assert_includes details, "required_ruby_version"
    assert_includes details, "metadata[changelog_uri]"
    assert_match(/packages development material: .*(test|dev)\//, details)
  end

  test "missing LICENSE, tests and third-party notices are reported" do
    FileUtils.rm_f(File.join(@gem, "LICENSE"))
    FileUtils.rm_rf(File.join(@gem, "test"))
    write(@gem, "THIRD_PARTY_NOTICES.md", "shadcn/ui only\n")
    write(@gem, "lib/chadcn/icon.rb", "module Chadcn\n  ICON = 'lucide-check' # from radix\nend\n")
    codes, _, result = check

    assert_includes codes, "GEMSPEC_LICENSE"
    assert_includes codes, "GEM_NO_TESTS"
    missing = result["findings"].select { |f| f["code"] == "GEM_NOTICES" }.map { |f| f["detail"] }

    assert(missing.any? { |d| d.include?("Lucide") })
    assert(missing.any? { |d| d.include?("Radix") })
    assert(missing.none? { |d| d.include?("shadcn/ui") })
  end

  test "no gemspec, a broken gemspec and a missing directory each get their own code" do
    FileUtils.rm_f(File.join(@gem, "phlex-x.gemspec"))

    assert_includes check[0], "GEMSPEC_MISSING"
    write(@gem, "phlex-x.gemspec", "raise 'boom'\n")

    assert_includes check[0], "GEMSPEC_UNLOADABLE"
    assert_equal [ "GEM_NOT_FOUND" ], check(gem_dir: File.join(@dir, "nope"))[0]
  end

  test "the codes the skill promises and the codes the script emits are the same set" do
    script = File.read(SCRIPT)
    emitted = script.scan(/"((?:GEM|GEMSPEC)_[A-Z_]+)"/).flatten.uniq
    skill = File.read(TOOLING_ROOT.join(".ai/skills/ruby-gem-conventions/SKILL.md"))
    promised = skill.scan(/\b((?:GEM|GEMSPEC)_[A-Z_]+)\b/).flatten.uniq - [ "GEMSPEC_*" ]

    assert_empty promised - emitted, "skill names codes the script never emits"
    assert_empty emitted - promised - [ "GEMSPEC_FIELD", "GEMSPEC_FILES", "GEMSPEC_UNLOADABLE", "GEMSPEC_MISSING", "GEM_NOT_FOUND" ], "script emits codes the skill does not map to a rule"
    assert_match(/GEMSPEC_\*/, skill, "skill must say the GEMSPEC_* family belongs to R7")
  end
end
