# frozen_string_literal: true

require_relative "../engine/engine_helper"
require "rails/generators/test_case"
require "generators/chadcn/eject/eject_generator"

class EjectGeneratorTest < Rails::Generators::TestCase
  tests Chadcn::Generators::EjectGenerator
  destination File.join(Dir.tmpdir, "chadcn-eject-destination-#{Process.pid}")

  Overrides = Chadcn::Overrides
  DIR = "app/components/chadcn"

  setup { prepare_destination }

  Minitest.after_run { FileUtils.rm_rf(destination_root) }

  def ejected(rel) = File.read(File.join(destination_root, DIR, rel))

  def gem_file(rel) = File.read(File.join(Overrides::GEM_DIR, rel))

  def run_failing_generator(args)
    error = nil
    stderr = capture(:stderr) { error = assert_raises(SystemExit) { run_generator args } }

    refute_predicate error, :success?
    stderr
  end

  def eject(*args) = run_generator([ *args, "--dir", DIR ])

  test "a leaf is copied under the override directory with a header that records the version and the digest of its source" do
    eject "button"

    header = Overrides.parse_header(ejected("button.rb"))

    assert_equal Chadcn::VERSION, header[:version]
    assert_equal "lib/chadcn/button.rb", header[:source]
    assert_equal Overrides.digest(gem_file("button.rb")), header[:digest]
    assert_equal gem_file("button.rb"), Overrides.strip_header(ejected("button.rb"))
  end

  test "the header keeps the frozen string literal magic comment effective" do
    path = File.join(destination_root, DIR, "probe.rb")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{Overrides.header(version: '0', source: 'x', text: '')}\n# frozen_string_literal: true\n\nLITERAL = 'lit'\n")
    probe = Module.new
    probe.module_eval(File.read(path), path)

    assert_predicate probe::LITERAL, :frozen?
  end

  test "a compound root is ejected with all its nested parts" do
    eject "dialog"

    expected = Overrides.unit_files("dialog")

    assert_operator expected.size, :>, 5
    assert_equal expected, Dir.glob("**/*.rb", base: File.join(destination_root, DIR)).sort
    expected.each { |rel| assert Overrides.parse_header(ejected(rel)), "#{rel} carries a header" }
  end

  test "one part can be ejected alone" do
    eject "dialog/content"

    assert_equal [ "dialog/content.rb" ], Dir.glob("**/*.rb", base: File.join(destination_root, DIR))
  end

  test "several components, in any spelling, in one run" do
    eject "Button", "alert-dialog", "AspectRatio", "Dialog::Content"

    assert_path_exists File.join(destination_root, DIR, "button.rb")
    assert_path_exists File.join(destination_root, DIR, "alert_dialog.rb")
    assert_path_exists File.join(destination_root, DIR, "aspect_ratio.rb")
    assert_path_exists File.join(destination_root, DIR, "dialog/content.rb")
  end

  test "an existing file is never overwritten without --force, and nothing is written for the other components" do
    eject "button"
    File.write(File.join(destination_root, DIR, "button.rb"), "# mine\n")

    stderr = run_failing_generator([ "badge", "button", "--dir", DIR ])

    assert_includes stderr, "--force"
    assert_equal "# mine\n", ejected("button.rb")
    refute_path_exists File.join(destination_root, DIR, "badge.rb")
  end

  test "--force overwrites the file" do
    eject "button"
    File.write(File.join(destination_root, DIR, "button.rb"), "# mine\n")

    eject "button", "--force"

    assert_equal Overrides.digest(gem_file("button.rb")), Overrides.parse_header(ejected("button.rb"))[:digest]
  end

  test "an unknown component and the gem's own infrastructure fail with the reason" do
    assert_includes run_failing_generator([ "nope", "--dir", DIR ]), "nope is not a chadcn component"
    assert_includes run_failing_generator([ "base", "--dir", DIR ]), "base is not a chadcn component"
    assert_includes run_failing_generator([ "dialog/nope", "--dir", DIR ]), "dialog/nope is not a chadcn component"
    assert_includes run_failing_generator([ "../base", "--dir", DIR ]), "not a chadcn component"
    assert_includes run_failing_generator([ "--dir", DIR ]), "name the components"
    refute_path_exists File.join(destination_root, DIR)
  end

  test "--list shows the ejectable components and marks the ejected ones" do
    eject "button", "dialog/content"
    output = eject("--list")

    assert_match(/^\s+button\s+ejected$/, output)
    assert_match(/^\s+card\s*$/, output)
    assert_includes output, "Ejected parts: dialog/content"
    refute_match(/^\s+base\b/, output)
  end

  test "--list works before anything is ejected" do
    output = eject("--list")

    assert_match(/^\s+button\s*$/, output)
    assert_includes output, "(does not exist yet)"
  end

  test "--diff shows how the copy differs from the gem" do
    eject "badge"
    File.write(File.join(destination_root, DIR, "badge.rb"), ejected("badge.rb").sub("class ", "# changed\nclass "))

    output = eject("badge", "--diff")

    assert_includes output, "+# changed"
  end

  test "--diff of an untouched copy says it is the same as the gem's file" do
    eject "badge"

    assert_includes eject("badge", "--diff"), "same as the gem's file"
  end

  test "--skip leaves existing files alone and writes the rest" do
    eject "button"
    File.write(File.join(destination_root, DIR, "button.rb"), "# mine\n")
    eject "badge", "button", "--skip"

    assert_equal "# mine\n", ejected("button.rb")
    assert_path_exists File.join(destination_root, DIR, "badge.rb")
  end

  test "--pretend writes nothing" do
    eject "button", "--pretend"

    refute_path_exists File.join(destination_root, DIR, "button.rb")
  end

  test "ejecting a module the gem classes include warns that edits need a restart" do
    assert_includes eject("direction/consumer"), "only after a restart"
  end

  test "ejecting sonner takes its Toaster alias along" do
    eject "sonner"

    assert_path_exists File.join(destination_root, DIR, "toaster.rb")
    assert_path_exists File.join(destination_root, DIR, "sonner/toaster.rb")
  end

  test "--diff names a component that is not ejected" do
    assert_includes eject("badge", "--diff"), "is not ejected"
  end

  test "the generator writes to the configured override directory when --dir is not given" do
    dir = File.join(destination_root, "custom/ui")
    config = Chadcn.config
    config.define_singleton_method(:override_dir) { dir }
    run_generator [ "badge" ]

    assert_path_exists File.join(dir, "badge.rb")
  ensure
    config.singleton_class.remove_method(:override_dir)
  end
end
