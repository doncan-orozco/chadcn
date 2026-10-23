# frozen_string_literal: true

require_relative "../engine/engine_helper"
require "rails/generators/test_case"
require "generators/chadcn/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Chadcn::Generators::InstallGenerator
  destination File.join(Dir.tmpdir, "chadcn-generator-destination-#{Process.pid}")

  TAILWIND_ENTRY = <<~CSS
    @import url("https://fonts.googleapis.com/css2?family=Manrope&display=swap");
    @import "tailwindcss";

    @import "./components/other.css";
  CSS

  SUCCESS_LINE = "Installed. Your app just got a jawline."
  REFRESH_REMINDER = "Run the generator again after updating the gem: it refreshes the copied JavaScript."

  # The booted test app configures a custom theme_dir; the generator reads it, so each test starts from "not configured".
  setup do
    @configured_theme_dir = Rails.application.config.chadcn.theme_dir
    Rails.application.config.chadcn.theme_dir = nil
    prepare_destination
    write("app/assets/tailwind/application.css", TAILWIND_ENTRY)
  end

  teardown { Rails.application.config.chadcn.theme_dir = @configured_theme_dir }

  Minitest.after_run { FileUtils.rm_rf(destination_root) }

  def css = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))

  def write(path, content)
    full = File.join(destination_root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  # The generator has to fail loudly: a non-zero exit (scripted installs, CI) and the reason on stderr.
  def run_failing_generator(args = [])
    error = nil
    stderr = capture(:stderr) { error = assert_raises(SystemExit) { run_generator args } }

    refute_predicate error, :success?
    stderr
  end

  def snapshot
    Dir.glob("**/*", base: destination_root).select { |path| File.file?(File.join(destination_root, path)) }.sort.to_h do |path|
      [ path, File.read(File.join(destination_root, path)) ]
    end
  end

  # The block is the same on every machine: the engine bundle (whose engine.css carries the self-relative @source for the gem's
  # Ruby files) and the theme, both relative to the app.
  MANAGED_BLOCK = [
    "/* chadcn:start (managed by rails g chadcn:install) */",
    %(@import "../builds/tailwind/chadcn";),
    %(@import "./theme/theme.css";),
    "/* chadcn:end */"
  ].freeze

  test "writes one block after the tailwind import with the engine bundle and the theme" do
    run_generator

    lines = css.lines.map(&:chomp)
    start = lines.index { |line| line.start_with?("/* chadcn:start") }

    refute_nil start

    assert_equal %(@import "tailwindcss";), lines[start - 1]
    assert_equal MANAGED_BLOCK, lines[start..(start + 3)]
    assert_includes css, %(@import "./components/other.css";), "the rest of the file is untouched"
    assert_equal 1, css.scan("chadcn:start").size
  end

  test "a gem installed outside the app leaves no machine-specific path in the entry file" do
    refute Chadcn.root.to_s.start_with?(destination_root), "the gem has to live outside the app, as a git or RubyGems install does"
    run_generator
    block = css[%r{/\* chadcn:start.*chadcn:end \*/}m]

    refute_includes block, "@source"
    refute_includes css, Chadcn.root.to_s
    block.scan(/"([^"]+)"/).flatten.each do |path|
      resolved = File.expand_path(path, File.join(destination_root, "app/assets/tailwind"))

      assert resolved.start_with?("#{destination_root}/"), "#{path} leaves the app"
    end
  end

  test "copies the default theme and presets into the host" do
    run_generator

    assert_file "app/assets/tailwind/theme/theme.css", /theme:colors:start/
    assert_file "app/assets/tailwind/theme/presets/slate.css"
    shipped = Chadcn.root.join("app/assets/tailwind/chadcn/presets").children.map { |file| file.basename.to_s }.sort

    assert_equal shipped, Dir.children(File.join(destination_root, "app/assets/tailwind/theme/presets")).sort
    assert_no_file "app/assets/tailwind/theme/tokens.css"
  end

  test "is idempotent: a second run changes nothing" do
    run_generator
    first = snapshot
    output = run_generator

    assert_equal first, snapshot
    assert_match(%r{identical\s+app/assets/tailwind/application.css}, output)
  end

  test "a clean install ends with the success line, after the next steps" do
    write("config/importmap.rb", %(pin "application"\n))
    lines = run_generator.lines.map(&:chomp).reject(&:empty?)

    assert_equal SUCCESS_LINE, lines[-1]
    assert_match(/restart the server/, lines[-2])
  end

  test "a second clean run says it again: nothing was skipped" do
    write("config/importmap.rb", %(pin "application"\n))
    run_generator

    assert_includes run_generator, SUCCESS_LINE
  end

  test "no success line when the generator kept an edited theme file" do
    write("config/importmap.rb", %(pin "application"\n))
    write("app/assets/tailwind/theme/theme.css", "/* my own colors */\n")

    refute_includes run_generator, SUCCESS_LINE
  end

  test "no success line when the JavaScript pipeline is unknown" do
    output = run_generator

    assert_includes output, "No importmap or jsbundling esbuild setup found"
    refute_includes output, SUCCESS_LINE
  end

  test "no success line with a theme_dir hint" do
    write("config/importmap.rb", %(pin "application"\n))

    refute_includes run_generator(%w[--theme-dir config/theme]), SUCCESS_LINE
  end

  test "no success line with --pretend" do
    write("config/importmap.rb", %(pin "application"\n))

    refute_includes run_generator(%w[--pretend]), SUCCESS_LINE
  end

  test "no success line when the generator kept an edited preset" do
    write("config/importmap.rb", %(pin "application"\n))
    write("app/assets/tailwind/theme/presets/slate.css", "/* my own slate */\n")
    output = run_generator

    assert_file "app/assets/tailwind/theme/presets/slate.css", /my own slate/
    refute_includes output, SUCCESS_LINE
  end

  test "keeps the theme the developer edited" do
    run_generator
    write("app/assets/tailwind/theme/theme.css", "/* my own colors */\n")
    run_generator

    assert_file "app/assets/tailwind/theme/theme.css", /my own colors/
  end

  test "rewrites an older block that still carries an @source line but leaves the rest alone" do
    run_generator
    older = css.sub("#{MANAGED_BLOCK.first}\n", %(#{MANAGED_BLOCK.first}\n@source "../../../old/gem/lib";\n))
    write("app/assets/tailwind/application.css", older)
    output = run_generator

    assert_match(%r{update\s+app/assets/tailwind/application.css}, output)
    refute_includes css, "@source"
    assert_equal 1, css.scan("chadcn:start").size
    assert_includes css, %(@import "./components/other.css";)
  end

  test "honours --css and --theme-dir" do
    write("app/assets/stylesheets/tw.css", %(@import "tailwindcss";\n))
    run_generator %w[--css app/assets/stylesheets/tw.css --theme-dir config/theme]
    entry = File.read(File.join(destination_root, "app/assets/stylesheets/tw.css"))

    assert_includes entry, %(@import "../builds/tailwind/chadcn";)
    assert_includes entry, %(@import "../../../config/theme/theme.css";)
    assert_file "config/theme/theme.css"
  end

  test "accepts tailwind imports with options and keeps the block right after them" do
    write("app/assets/tailwind/application.css", %(@import "tailwindcss" source("../../app");\n@import "./other.css";\n))
    run_generator
    lines = css.lines.map(&:chomp)

    assert_equal %(@import "tailwindcss" source("../../app");), lines[0]
    assert_match(/chadcn:start/, lines[1])
    assert_equal %(@import "./other.css";), lines.last
  end

  test "keeps CRLF files consistent and idempotent" do
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\r\n@import "./other.css";\r\n))
    run_generator
    first = File.binread(File.join(destination_root, "app/assets/tailwind/application.css"))
    run_generator

    refute_match(/(?<!\r)\n/, first, "a bare LF was mixed into a CRLF file")
    assert_includes first, "chadcn:start"
    assert_equal first, File.binread(File.join(destination_root, "app/assets/tailwind/application.css"))
  end

  test "refuses a start marker without its end marker instead of reporting identical" do
    run_generator
    broken = css.sub("/* chadcn:end */", "")
    write("app/assets/tailwind/application.css", broken)
    output = run_failing_generator

    assert_match(/missing, repeated or misordered/, output)
    assert_equal broken, css
  end

  test "markers in the wrong order fail instead of reporting identical" do
    start = "/* chadcn:start (managed by rails g chadcn:install) */"
    write("app/assets/tailwind/application.css", %(@import "tailwindcss";\n/* chadcn:end */\n#{start}\n))
    before = css
    output = run_failing_generator

    assert_match(/missing, repeated or misordered/, output)
    assert_equal before, css
  end

  test "a repeated block fails instead of being half-updated" do
    run_generator
    write("app/assets/tailwind/application.css", css + css.lines.grep_v(/tailwindcss";/).join)

    assert_match(/missing, repeated or misordered/, run_failing_generator)
  end

  test "paths that cannot be expressed relative to the css file fail with a message, not a stack overflow" do
    original = Pathname.instance_method(:relative_path_from)
    Pathname.define_method(:relative_path_from) { |*| raise ArgumentError, "different prefix" }
    output = run_failing_generator

    assert_match(%r{cannot express .* relative to app/assets/tailwind/application\.css}, output)
    assert_match(%r{add @imports of app/assets/builds/tailwind/chadcn and app/assets/tailwind/theme/theme\.css}, output)
    refute_includes output, "@source"
  ensure
    Pathname.define_method(:relative_path_from, original)
  end

  test "--pretend changes no file" do
    before = snapshot
    run_generator %w[--pretend]

    assert_equal before, snapshot
  end

  test "absolute --css and --theme-dir paths are used as given" do
    elsewhere = Dir.mktmpdir("chadcn-elsewhere")
    File.write(File.join(elsewhere, "tw.css"), %(@import "tailwindcss";\n))
    run_generator [ "--css", File.join(elsewhere, "tw.css"), "--theme-dir", File.join(elsewhere, "theme") ]

    assert_includes File.read(File.join(elsewhere, "tw.css")), %(@import "./theme/theme.css";)
    assert_path_exists File.join(elsewhere, "theme/theme.css")
    assert_path_exists File.join(elsewhere, "theme/presets/slate.css")
  ensure
    FileUtils.remove_entry(elsewhere) if elsewhere
  end

  test "points at config.chadcn.theme_dir when the theme lives elsewhere" do
    output = run_generator %w[--theme-dir config/theme]

    assert_match(%r{config\.chadcn\.theme_dir = "config/theme"}, output)
  end

  test "uses config.chadcn.theme_dir when --theme-dir is not given and gives no hint" do
    Rails.application.config.chadcn.theme_dir = "config/theme"
    output = run_generator

    assert_file "config/theme/theme.css"
    assert_includes css, %(@import "../../../config/theme/theme.css";)
    assert_no_file "app/assets/tailwind/theme/theme.css"
    refute_match(/theme_dir/, output)
  end

  test "says nothing about theme_dir for the default location" do
    refute_match(/theme_dir/, run_generator)
  end

  test "fails with a clear message when the tailwind entry file is missing" do
    FileUtils.rm(File.join(destination_root, "app/assets/tailwind/application.css"))
    output = run_failing_generator

    assert_match(%r{not found: install tailwindcss-rails first \(bin/rails tailwindcss:install\)}, output)
    assert_no_file "app/assets/tailwind/theme/theme.css"
  end

  test "fails with a clear message when the entry file does not import tailwind" do
    write("app/assets/tailwind/application.css", "body { color: red; }\n")
    output = run_failing_generator

    assert_match(/does not contain @import "tailwindcss"/, output)
    assert_match(/chadcn:start/, output, "the message shows the lines to add by hand")
    assert_equal "body { color: red; }\n", css, "the file is left untouched"
  end

  ESBUILD_PACKAGE = <<~JSON
    {"scripts": {"build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds"}, "dependencies": {"@floating-ui/dom": "^1.8.0"}}
  JSON

  def esbuild_app(package: ESBUILD_PACKAGE)
    write("package.json", package)
    write("app/javascript/application.js", %(import "@hotwired/turbo-rails"\nimport "./controllers"\n))
  end

  test "an esbuild app gets the controllers and primitives as relative-import copies, registered and imported" do
    esbuild_app
    run_generator

    assert_file "app/javascript/controllers/chadcn/dialog_controller.js" do |source|
      assert_includes source, %(from "../../chadcn/primitives/presence")
      assert_match(%r{\A// Managed by}, source)
      refute_match(%r{from "(chadcn/primitives|controllers/chadcn)/}, source)
    end
    assert_file "app/javascript/controllers/chadcn/sheet_controller.js", %r{from "\./dialog_controller"}
    assert_file "app/javascript/chadcn/primitives/roving_focus.js", %r{from "\./direction"}
    assert_file "app/javascript/controllers/chadcn/index.js" do |source|
      assert_includes source, %(import { application } from "../application")
      assert_includes source, %(application.register("chadcn--dropdown-menu", DropdownMenuController))
    end
    assert_file "app/javascript/application.js", %r{import "\./controllers/chadcn"\n\z}
    assert_no_file "app/javascript/controllers/chadcn/index_controller.js"
  end

  test "every gem controller is registered in the esbuild index" do
    esbuild_app
    run_generator
    index = File.read(File.join(destination_root, "app/javascript/controllers/chadcn/index.js"))
    controllers = Chadcn.root.join("app/javascript/controllers/chadcn").children.map { |file| file.basename.to_s.delete_suffix("_controller.js") }

    controllers.each { |name| assert_includes index, "application.register(\"chadcn--#{name.tr('_', '-')}\"," }
  end

  test "no copy keeps an importmap-only specifier" do
    Chadcn::JsBundle.files(Chadcn.root).each do |path, content|
      refute_match(%r{["'](chadcn/primitives|controllers/chadcn)/}, content, path)
    end
  end

  test "specifiers are rewritten in every quote and import form" do
    source = %(import a from 'chadcn/primitives/x'\nimport "chadcn/primitives/y"\nconst m = await import("controllers/chadcn/z")\n)
    rewritten = Chadcn::JsBundle.send(:relative_specifiers, source, "app/javascript/controllers/chadcn")

    assert_equal %(import a from '../../chadcn/primitives/x'\nimport "../../chadcn/primitives/y"\nconst m = await import("./z")\n), rewritten
  end

  test "pnpm and bun lock files choose their package manager" do
    esbuild_app(package: %({"scripts": {"build": "esbuild"}}))
    write("pnpm-lock.yaml", "")

    assert_match(%r{pnpm add @floating-ui/dom}, run_generator(%w[--pretend]))
    FileUtils.rm(File.join(destination_root, "pnpm-lock.yaml"))
    write("bun.lockb", "")

    assert_match(%r{bun add @floating-ui/dom}, run_generator(%w[--pretend]))
  end

  test "a commented-out import does not count and a single-quoted one does" do
    esbuild_app
    write("app/javascript/application.js", %(// import "./controllers/chadcn"\n))
    run_generator

    assert_equal 2, File.read(File.join(destination_root, "app/javascript/application.js")).scan("./controllers/chadcn").size
    write("app/javascript/application.js", %(import './controllers/chadcn'\n))
    run_generator

    assert_equal 1, File.read(File.join(destination_root, "app/javascript/application.js")).scan("./controllers/chadcn").size
  end

  test "an esbuild app run twice changes nothing" do
    esbuild_app
    run_generator
    first = snapshot
    output = run_generator

    assert_equal first, snapshot
    assert_match(%r{identical\s+app/javascript/controllers/chadcn/dialog_controller.js}, output)
    assert_equal 1, File.read(File.join(destination_root, "app/javascript/application.js")).scan("controllers/chadcn").size
  end

  test "an esbuild run refreshes a copy that went stale" do
    esbuild_app
    run_generator
    write("app/javascript/chadcn/primitives/presence.js", "// stale\n")
    output = run_generator

    assert_match(%r{update\s+app/javascript/chadcn/primitives/presence.js}, output)
    assert_file "app/javascript/chadcn/primitives/presence.js", /export/
  end

  test "an esbuild app without floating-ui gets it from its package manager" do
    esbuild_app(package: %({"scripts": {"build": "esbuild app/javascript/*.*"}}))
    write("yarn.lock", "")
    output = run_generator %w[--pretend]

    assert_match(%r{run\s+yarn add @floating-ui/dom@\^1\.8\.0}, output)
  end

  test "the package manager follows the lock file" do
    esbuild_app(package: %({"scripts": {"build": "esbuild"}}))

    assert_match(%r{npm install @floating-ui/dom}, run_generator(%w[--pretend]))
  end

  test "an importmap app is left alone" do
    write("config/importmap.rb", %(pin "application"\n))
    write("package.json", ESBUILD_PACKAGE)
    run_generator

    assert_no_file "app/javascript/controllers/chadcn/dialog_controller.js"
  end

  test "--js importmap skips the JavaScript copies even when a build script exists" do
    esbuild_app
    run_generator %w[--js importmap]

    assert_no_file "app/javascript/controllers/chadcn/index.js"
  end

  test "an app without a detectable pipeline gets no JavaScript" do
    run_generator

    assert_no_file "app/javascript/controllers/chadcn/index.js"
  end

  test "--js esbuild without a package.json fails with a clear message" do
    output = run_failing_generator(%w[--js esbuild])

    assert_match(/package.json not found/, output)
    assert_no_file "app/javascript/controllers/chadcn/index.js"
    assert_no_file "app/javascript/chadcn/primitives/presence.js"
  end

  test "an esbuild app without application.js is told what to add" do
    write("package.json", ESBUILD_PACKAGE)
    output = run_generator

    assert_match(%r{add `import "\./controllers/chadcn"`}, output)
  end

  test "no success line when an esbuild app has no entry file to import into, and the notice copy is unchanged" do
    write("package.json", ESBUILD_PACKAGE)
    output = run_generator

    assert_includes output, "app/javascript/application.js not found: add `import \"./controllers/chadcn\"` to your JavaScript entry file."
    refute_includes output, SUCCESS_LINE
  end

  test "a clean esbuild install ends with the success line after the refresh reminder" do
    esbuild_app
    lines = run_generator.lines.map(&:chomp).reject(&:empty?)

    assert_equal SUCCESS_LINE, lines[-1]
    assert_equal REFRESH_REMINDER, lines[-2]
  end
end
