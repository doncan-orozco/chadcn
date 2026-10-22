# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "engine_helper"
require "generators/chadcn/eject/eject_generator"

# Ejected components (dev/decisions/eject-override.md): a file in the override directory replaces the gem's file of the same path.
# Zeitwerk loaders and the constants they define are process-global, so every Rails scenario boots its own application in a child
# process (CHILD below) and reports JSON; the in-process tests cover the settings, the file rules and the doctor check.
class EngineTest::Eject < Minitest::Test
  Overrides = Chadcn::Overrides
  Check = Chadcn::Doctor::Checks::Ejected
  Context = Chadcn::Doctor::Context
  LIB = File.expand_path("../../lib", __dir__)
  DIR = "app/components/chadcn"

  # A Rails application whose root is ARGV[0]; ARGV[1] names the scenario, ARGV[2] is "eager" or "lazy".
  CHILD = <<~'RUBY'
    require "json"
    require "logger"
    require "rails"
    require "chadcn"

    root, scenario, mode = ARGV
    ENV["RAILS_ENV"] = "test"
    class ChildApp < Rails::Application
      config.root = ARGV[0]
      config.eager_load = ARGV[2] == "eager"
      config.enable_reloading = ARGV[1].start_with?("reload")
      config.logger = Logger.new(IO::NULL)
      config.secret_key_base = "test"
    end

    def source(constant) = constant.instance_method(:view_template).source_location.first
    result = {}
    begin
      ChildApp.initialize!
      result["boot"] = "ok"
      button = Chadcn::Button
      result["button"] = button.new { "x" }.call
      result["button_source"] = source(button)
      result["card_source"] = source(Chadcn::Card)
      result["card"] = Chadcn::Card.new { "c" }.call
      result["dialog_title_source"] = source(Chadcn::Dialog::Title)
      result["dialog_content_source"] = source(Chadcn::Dialog::Content)
      result["footer_uses_ejected_button"] = Chadcn::Dialog::Footer.new(show_close_button: true).call.include?("data-ejected")
      result["toaster_same_class"] = defined?(Chadcn::Toaster) ? Chadcn::Toaster.equal?(Chadcn::Sonner::Toaster) : nil
      result["override_dir"] = Chadcn.config.override_dir
      result["main_loader_roots"] = Rails.autoloaders.main.dirs.grep(%r{/components/chadcn\z})
      if scenario == "reload_sonner"
        path = File.join(root, "app/components/chadcn/sonner/toaster.rb")
        File.write(path, File.read(path) + "\nChadcn::Sonner::Toaster::EDITED = 'yes'\n")
        Rails.application.reloader.reload!
        result["toaster_edited"] = Chadcn::Toaster.const_defined?(:EDITED, false)
        result["toaster_same_after"] = Chadcn::Toaster.equal?(Chadcn::Sonner::Toaster)
      end
      if scenario == "reload"
        path = File.join(root, "app/components/chadcn/button.rb")
        File.write(path, File.read(path).sub('ejected: "yes"', 'ejected: "edited"'))
        Rails.application.reloader.reload!
        result["after_edit"] = Chadcn::Button.new { "x" }.call
        result["after_edit_card_source"] = source(Chadcn::Card)

        # A file added while the server runs shadows nothing: the gem's loader registered its constant at boot (documented limit).
        File.write(File.join(root, "app/components/chadcn/badge.rb"), "class Chadcn::Badge < Chadcn::Base\n" \
                   "  def view_template(&) = span(data_ejected: 'late', &)\nend\n")
        Rails.application.reloader.reload!
        result["after_add_badge_source"] = source(Chadcn::Badge)

        # A file removed while the server runs leaves nothing to load (documented limit).
        File.delete(path)
        Rails.application.reloader.reload!
        result["after_remove"] = begin
          Chadcn::Button
        rescue NameError => e
          "NameError: #{e.message}"
        end
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      result["error"] = "#{e.class}: #{e.message}"
    end
    puts JSON.generate(result)
  RUBY

  # Railties are loaded and a component is used, but no application is initialized.
  EARLY = <<~RUBY
    require "json"
    require "rails"
    require "chadcn"

    puts JSON.generate("button" => Chadcn::Button.new { "x" }.call)
  RUBY

  PLAIN = <<~RUBY
    require "json"
    require "chadcn"

    result = {}
    Chadcn.eager_load if ARGV[1] == "eager"
    result["button"] = Chadcn::Button.new { "x" }.call
    result["button_source"] = Chadcn::Button.instance_method(:view_template).source_location.first
    result["card_source"] = Chadcn::Card.instance_method(:view_template).source_location.first
    result["rails"] = defined?(Rails).inspect
    puts JSON.generate(result)
  RUBY

  def setup
    @root = Pathname.new(Dir.mktmpdir("chadcn-eject-app"))
    @files = Dir.mktmpdir("chadcn-eject-scripts")
  end

  def teardown
    FileUtils.remove_entry(@root)
    FileUtils.remove_entry(@files)
  end

  def eject(*names, root: @root, force: false)
    args = [ *names, "--dir", DIR, "--quiet" ]
    args << "--force" if force
    Chadcn::Generators::EjectGenerator.start(args, destination_root: root.to_s)
  end

  def override(rel) = @root.join(DIR, rel)

  def edit(rel, from, to) = override(rel).write(override(rel).read.sub(from, to))

  # macOS reports temporary directories through /private; the scenarios compare paths below the app root.
  def under_root(path) = File.realpath(path).sub(File.realpath(@root), @root.to_s)

  def child(script, *, env: {})
    path = File.join(@files, "child.rb")
    File.write(path, script)
    out, err, status = Open3.capture3({ "RAILS_ENV" => "test" }.merge(env), RbConfig.ruby, "-I", LIB, path, *)

    assert_predicate status, :success?, "child failed: #{err}"
    JSON.parse(out.lines.last)
  end

  def rails_app(scenario, mode = "lazy") = child(CHILD, @root.to_s, scenario, mode)

  %w[lazy eager].each do |mode|
    define_method(:"test_an_ejected_button_with_changed_markup_renders_while_card_comes_from_the_gem_#{mode}") do
      eject "button"
      edit("button.rb", 'data: { slot: "button",', 'data: { slot: "button", ejected: "yes",')
      result = rails_app("boot", mode)

      assert_equal "ok", result["boot"], result["error"]
      assert_includes result["button"], 'data-ejected="yes"'
      assert_includes result["button"], "bg-primary", "the copy still renders the gem's classes"
      assert_equal override("button.rb").to_s, under_root(result["button_source"])
      assert_equal File.join(Overrides::GEM_DIR, "card.rb"), result["card_source"]
      assert_includes result["card"], 'data-slot="card"'
      assert result["footer_uses_ejected_button"], "gem components that render a Button use the ejected one"
      roots = result["main_loader_roots"].map { |dir| under_root(dir) }

      assert_equal [ override("").to_s.chomp("/") ], roots
    end

    define_method(:"test_a_compound_root_is_ejected_with_its_parts_and_the_rest_stays_in_the_gem_#{mode}") do
      eject "dialog"
      edit("dialog/title.rb", "class ", "# ejected title\nclass ")
      result = rails_app("boot", mode)

      assert_equal "ok", result["boot"], result["error"]
      assert_includes result["dialog_title_source"], "#{DIR}/dialog/title.rb"
      assert_includes result["dialog_content_source"], "#{DIR}/dialog/content.rb"
      assert_equal File.join(Overrides::GEM_DIR, "button.rb"), File.realpath(result["button_source"])
    end

    define_method(:"test_one_ejected_part_leaves_the_rest_of_its_component_in_the_gem_#{mode}") do
      eject "dialog/content"
      result = rails_app("boot", mode)

      assert_equal "ok", result["boot"], result["error"]
      assert_includes result["dialog_content_source"], "#{DIR}/dialog/content.rb"
      assert_equal File.join(Overrides::GEM_DIR, "dialog/title.rb"), result["dialog_title_source"]
    end

    define_method(:"test_every_component_ejected_at_once_boots_and_loads_#{mode}") do
      eject(*Overrides.components)
      result = rails_app("boot", mode)

      assert_equal "ok", result["boot"], result["error"]
      assert_includes result["button_source"], "#{DIR}/button.rb"
      assert_includes result["card_source"], "#{DIR}/card.rb"
    end

    define_method(:"test_without_an_override_directory_everything_loads_from_the_gem_#{mode}") do
      result = rails_app("boot", mode)

      assert_equal "ok", result["boot"], result["error"]
      assert_equal File.join(Overrides::GEM_DIR, "button.rb"), result["button_source"]
      assert_empty result["main_loader_roots"]
    end
  end

  def test_editing_an_ejected_file_reloads_while_adding_or_removing_one_needs_a_restart
    eject "button"
    edit("button.rb", 'data: { slot: "button",', 'data: { slot: "button", ejected: "yes",')
    result = rails_app("reload")

    assert_equal "ok", result["boot"], result["error"]
    assert_includes result["button"], 'data-ejected="yes"'
    assert_includes result["after_edit"], 'data-ejected="edited"', "an edit is picked up without a restart"
    assert_equal File.join(Overrides::GEM_DIR, "card.rb"), result["after_edit_card_source"]
    assert_equal File.join(Overrides::GEM_DIR, "badge.rb"), result["after_add_badge_source"], "a file added at runtime is not active: restart"
    assert_match(/NameError: uninitialized constant Chadcn::Button/, result["after_remove"], "a file removed at runtime leaves no Button: restart")
  end

  def test_a_component_used_before_the_application_initializes_still_loads
    assert_includes child(EARLY)["button"], 'data-slot="button"'
  end

  def test_referencing_a_component_in_an_environment_file_raises_when_an_override_directory_exists
    eject "button"
    @root.join("config/environments").mkpath
    @root.join("config/environments/test.rb").write("Chadcn::Card\n")
    result = rails_app("boot")

    assert_match(/LateSettingError: chadcn components were loaded before the application initialized/, result["error"])
  end

  def test_referencing_a_component_in_an_environment_file_is_fine_without_an_override_directory
    @root.join("config/environments").mkpath
    @root.join("config/environments/test.rb").write("Chadcn::Card\n")

    assert_equal "ok", rails_app("boot")["boot"]
  end

  def test_an_ejected_sonner_carries_the_toaster_alias_and_the_edit_reloads_through_it
    eject "sonner"
    result = rails_app("reload_sonner")

    assert_equal "ok", result["boot"], result["error"]
    assert result["toaster_same_class"], "Toaster is the ejected Sonner::Toaster"
    assert result["toaster_edited"], "an edit of the ejected Sonner::Toaster shows through Toaster after a reload"
    assert result["toaster_same_after"]
  end

  def test_a_toaster_part_ejected_alone_takes_the_alias_along
    eject "sonner/toaster"

    assert_equal %w[sonner/toaster.rb toaster.rb], Dir.glob("**/*.rb", base: @root.join(DIR).to_s).sort
  end

  def test_the_override_directory_can_be_configured_in_the_environment_file
    eject "button"
    FileUtils.mv(override(""), @root.join("components"))
    @root.join("config/environments").mkpath
    @root.join("config/environments/test.rb").write("Rails.application.configure { config.chadcn.override_dir = 'components' }\n")
    result = rails_app("boot")

    assert_equal "ok", result["boot"], result["error"]
    assert_equal @root.join("components").to_s, under_root(result["override_dir"])
    assert_includes result["button_source"], "components/button.rb"
  end

  def test_a_chadcn_configure_block_before_boot_sets_the_directory
    eject "button"
    FileUtils.mv(override(""), @root.join("components"))
    @root.join("config/environments").mkpath
    @root.join("config/environments/test.rb").write("Chadcn.configure { |c| c.override_dir = #{@root.join('components').to_s.inspect} }\n")
    result = rails_app("boot")

    assert_equal "ok", result["boot"], result["error"]
    assert_includes result["button_source"], "components/button.rb"
  end

  def test_setting_the_directory_from_an_initializer_raises_instead_of_being_ignored
    @root.join("config/initializers").mkpath
    @root.join("config/initializers/phlex.rb").write("Rails.application.config.chadcn.override_dir = 'late'\n")
    result = rails_app("boot")

    assert_match(/LateSettingError: config.chadcn.override_dir was changed after/, result["error"])
  end

  def test_configuring_the_directory_from_an_initializer_raises_instead_of_being_ignored
    @root.join("config/initializers").mkpath
    @root.join("config/initializers/phlex.rb").write("Chadcn.configure { |c| c.override_dir = '/late' }\n")
    result = rails_app("boot")

    assert_match(/LateSettingError: override_dir was set after chadcn loaded/, result["error"])
  end

  def test_the_setter_raises_once_the_loader_is_set_up_unless_the_value_is_unchanged
    config = Chadcn.config
    current = config.override_dir

    assert_predicate Chadcn, :setup?
    error = assert_raises(Chadcn::Configuration::LateSettingError) { config.override_dir = "/elsewhere" }
    assert_includes error.message, "config/application.rb"
    config.override_dir = current

    assert_equal current, config.override_dir
  end

  %w[lazy eager].each do |mode|
    define_method(:"test_a_plain_phlex_process_reads_the_directory_from_the_environment_#{mode}") do
      eject "button"
      edit("button.rb", 'data: { slot: "button",', 'data: { slot: "button", ejected: "yes",')
      result = child(PLAIN, "-", mode, env: { "CHADCN_OVERRIDE_DIR" => override("").to_s })

      assert_includes result["button"], 'data-ejected="yes"'
      assert_equal "nil", result["rails"], "no Rails involved"
      assert_equal File.join(Overrides::GEM_DIR, "card.rb"), result["card_source"]
    end
  end

  def test_a_plain_phlex_process_without_the_variable_loads_the_gem
    result = child(PLAIN, "-", "lazy", env: { "CHADCN_OVERRIDE_DIR" => "" })

    assert_equal File.join(Overrides::GEM_DIR, "button.rb"), result["button_source"]
  end

  def test_a_missing_override_directory_is_ignored
    result = child(PLAIN, "-", "lazy", env: { "CHADCN_OVERRIDE_DIR" => @root.join("nope").to_s })

    assert_equal File.join(Overrides::GEM_DIR, "button.rb"), result["button_source"]
  end

  def test_the_gem_files_an_override_directory_shadows
    eject "dialog", "button"
    gem = Overrides::GEM_DIR

    shadowed = Overrides.shadowed(@root.join(DIR).to_s)

    assert_includes shadowed, File.join(gem, "button.rb")
    assert_includes shadowed, File.join(gem, "dialog.rb")
    assert_includes shadowed, File.join(gem, "dialog"), "a compound root takes its directory with it"
    refute_includes shadowed, File.join(gem, "card.rb")
  end

  def test_a_part_ejected_alone_shadows_only_its_file
    eject "dialog/content"

    assert_equal [ File.join(Overrides::GEM_DIR, "dialog/content.rb") ], Overrides.shadowed(@root.join(DIR).to_s)
    assert_equal [ "dialog/content" ], Overrides.ejected_units(@root.join(DIR).to_s)
  end

  def test_components_exclude_the_infrastructure_and_include_every_family
    components = Overrides.components

    assert_includes components, "button"
    assert_includes components, "alert_dialog"
    assert_empty components & Overrides::INFRASTRUCTURE
    assert(components.all? { |name| Overrides.ejectable?(name) })
    refute Overrides.ejectable?("base")
    refute Overrides.ejectable?("../base")
  end

  # #205 moved overrides.rb and js_bundle.rb into the gem loader's directory: they are tooling, never ejectable or shadowable.
  def test_the_plain_ruby_helpers_are_neither_components_nor_shadowable
    %w[js_bundle overrides configuration].each do |name|
      refute_includes Overrides.components, name
      refute Overrides.ejectable?(name), "#{name} is infrastructure"
    end

    FileUtils.mkdir_p(override("."))
    override("js_bundle.rb").write("# frozen_string_literal: true\n")
    override("overrides.rb").write("# frozen_string_literal: true\n")

    assert_empty Overrides.shadowed(@root.join(DIR).to_s)
  end

  # The doctor check

  def check(gem_dir: Overrides::GEM_DIR, version: "0.1.0")
    Check.call(Context.new(root: @root, gems: { "chadcn" => Gem::Version.new(version) }), override_dir: @root.join(DIR).to_s, gem_dir: gem_dir)
  end

  def test_doctor_passes_when_nothing_is_ejected
    assert_equal :pass, check.status
    assert_includes check.message, "nothing ejected"
  end

  def test_doctor_passes_for_fresh_copies
    eject "button", "dialog"

    assert_equal :pass, check.status
    assert_includes check.message, "button, dialog"
  end

  def test_doctor_is_registered_in_the_report
    names = Chadcn::Doctor.check_classes.map { |klass| klass::NAME }

    assert_includes names, Check::NAME
  end

  def test_doctor_warns_about_a_copy_whose_gem_file_changed
    eject "button"
    gem_dir = Pathname.new(Dir.mktmpdir("chadcn-newer-gem"))
    FileUtils.cp_r("#{Overrides::GEM_DIR}/.", gem_dir)
    gem_dir.join("button.rb").write("#{gem_dir.join('button.rb').read}# new in 0.2.0\n")
    result = check(gem_dir: gem_dir.to_s, version: "0.2.0")

    assert_equal :warn, result.status
    assert_includes result.message, "button (button.rb) changed upstream: copied from chadcn 0.1.0, installed 0.2.0"
    assert_includes result.fix, "--diff"
  ensure
    FileUtils.remove_entry(gem_dir) if gem_dir
  end

  def test_doctor_does_not_warn_about_a_new_gem_version_that_left_the_file_alone
    eject "button"

    assert_equal :pass, check(version: "9.9.9").status
  end

  def test_doctor_warns_about_gem_parts_an_ejected_unit_lacks
    eject "dialog"
    override("dialog/title.rb").delete
    result = check

    assert_equal :warn, result.status
    assert_includes result.message, "the gem has parts dialog lacks (dialog/title.rb)"
  end

  def test_doctor_does_not_ask_a_part_ejected_alone_for_its_siblings
    eject "dialog/content"

    assert_equal :pass, check.status
  end

  def test_doctor_warns_about_a_copy_without_a_header
    eject "button"
    override("button.rb").write(Overrides.strip_header(override("button.rb").read))
    result = check

    assert_equal :warn, result.status
    assert_includes result.message, "has no ejected header"
  end

  def test_doctor_warns_about_a_copy_whose_gem_file_is_gone
    eject "badge"
    gem_dir = Pathname.new(Dir.mktmpdir("chadcn-gem-without-badge"))
    FileUtils.cp_r("#{Overrides::GEM_DIR}/.", gem_dir)
    gem_dir.join("badge.rb").delete
    result = check(gem_dir: gem_dir.to_s)

    assert_equal :warn, result.status
    assert_includes result.message, "badge.rb was ejected from chadcn but the gem no longer has that file"
  ensure
    FileUtils.remove_entry(gem_dir) if gem_dir
  end

  def test_doctor_leaves_the_apps_own_file_next_to_an_ejected_unit_alone
    eject "dialog"
    override("dialog/my_extra.rb").write("class Chadcn::Dialog::MyExtra < Chadcn::Base; end\n")

    assert_equal :pass, check.status
  end

  def test_a_file_that_shadows_gem_infrastructure_shadows_nothing
    override("base.rb").dirname.mkpath
    override("base.rb").write("raise 'never loaded'\n")

    assert_empty Overrides.shadowed(@root.join(DIR).to_s)
  end

  def test_ejecting_sonner_includes_its_toaster_alias
    eject "sonner"

    assert_includes Overrides.unit_files("sonner"), "toaster.rb"
    assert_includes Overrides.shadowed(@root.join(DIR).to_s), File.join(Overrides::GEM_DIR, "toaster.rb")
    assert_equal :pass, check.status
  end

  def test_doctor_leaves_the_apps_own_components_alone
    override("my_card.rb").dirname.mkpath
    override("my_card.rb").write("class Chadcn::MyCard < Chadcn::Base; end\n")

    assert_equal :pass, check.status
  end

  def test_doctor_passes_without_a_configured_directory
    result = Check.call(Context.new(root: @root, gems: {}), override_dir: nil)

    assert_equal :pass, result.status
  end

  def test_the_doctor_task_covers_the_check_in_the_booted_application
    report = Chadcn::Doctor.run(Context.new(root: EngineTest::ROOT, theme_dir: EngineTest::THEME_DIR))

    assert(report.results.any? { |result| result.name == Check::NAME })
  end
end
