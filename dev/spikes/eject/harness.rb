# frozen_string_literal: true

# Child process of override_test.rb. One scenario per process (Zeitwerk and constants are global state).
#
#   ruby -Ilib harness.rb <overrides fixture|none> <eager|lazy> <ignore_before_setup|ignore_after_setup> [reload]
#
# It models the loader wiring of lib/chadcn.rb with a plain Zeitwerk::Loader rooted at lib/chadcn (namespace
# Chadcn); production uses Loader.for_gem, whose inflector maps version.rb, hence the explicit ignore
# of version.rb below. It adds what an override directory needs, so the production change can be judged against a running model:
#
#   1. the override directory is known BEFORE the gem loader's setup;
#   2. every gem file the override directory shadows is ignored by the gem loader (a compound root ignores file AND directory);
#   3. a second loader owns the override directory, mounted on the Chadcn namespace.
require "json"
require "pathname"
require "phlex"
require "tailwind_merge"
require "zeitwerk"

GEM_ROOT = File.expand_path("../../..", __dir__) # gems/chadcn; keeps asserted paths independent of the cwd
fixture, load_mode, ignore_timing, reload = ARGV
overrides = fixture == "none" ? nil : File.expand_path("fixtures/#{fixture}", __dir__)
gem_lib = File.expand_path("../../../lib/chadcn", __dir__)

module Chadcn
end

# Gem files shadowed by the override directory. A top-level file or directory name is a component; nested parts are
# shadowed one by one (dialog/content.rb) so the rest of the component keeps loading from the gem.
shadowed = lambda do |dir|
  next [] unless dir

  Dir.glob("**/*.rb", base: dir).flat_map do |rel|
    top = rel.split("/").first
    # A root override (dialog.rb next to dialog/) ejects the component as a unit: the gem's file and directory are ignored.
    if File.exist?(File.join(dir, "#{top}.rb"))
      [File.join(gem_lib, "#{top}.rb"), File.join(gem_lib, top)]
    else
      [File.join(gem_lib, rel)]
    end
  end.uniq.select { |path| File.exist?(path) }
end

gem_loader = Zeitwerk::Loader.new
gem_loader.tag = "chadcn-gem"
gem_loader.push_dir(gem_lib, namespace: Chadcn)
gem_loader.ignore(File.join(gem_lib, "engine.rb"), File.join(gem_lib, "engine"), File.join(gem_lib, "version.rb"))
shadowed_paths = shadowed.call(overrides)
# "reload" makes both loaders reloadable; "reload_override_only" is the production layout (the gem loader is not reloadable).
gem_loader.enable_reloading if reload == "reload"
gem_loader.ignore(*shadowed_paths) if ignore_timing == "ignore_before_setup" && shadowed_paths.any?
gem_loader.setup
ignore_after_error = nil
if ignore_timing == "ignore_after_setup" && overrides
  begin
    gem_loader.ignore(*shadowed_paths)
  rescue => e
    ignore_after_error = e.class.name
  end
end

override_loader = nil
if overrides
  override_loader = Zeitwerk::Loader.new
  override_loader.tag = "chadcn-overrides"
  override_loader.push_dir(overrides, namespace: Chadcn)
  override_loader.enable_reloading if %w[reload reload_override_only].include?(reload)
  override_loader.setup
end

eager_error = nil
if load_mode == "eager"
  begin
    gem_loader.eager_load
    override_loader&.eager_load
  rescue => e
    eager_error = "#{e.class}: #{e.message}"
  end
end

def render(component)
  component.call
rescue => e
  "#{e.class}: #{e.message[0, 120]}"
end

result = {"ignore_after_error" => ignore_after_error, "eager_error" => eager_error}
begin
  result["button"] = render(Chadcn::Button.new { "x" })
  result["dialog_ejected"] = Chadcn::Dialog.const_defined?(:EJECTED, false) ? Chadcn::Dialog::EJECTED : nil
  result["dialog_content_ejected"] = Chadcn::Dialog::Content.const_defined?(:EJECTED, false) ? Chadcn::Dialog::Content::EJECTED : nil
  result["dialog_title"] = Chadcn::Dialog::Title.name
  result["dialog_title_source"] = Chadcn::Dialog::Title.instance_method(:view_template).source_location&.first.to_s.sub(GEM_ROOT, ".")
  result["button_source"] = Chadcn::Button.instance_method(:view_template).source_location.first.sub(File.dirname(__dir__), "")
  # A non-ejected component (Card) that references the overridden constant still resolves through the namespace.
  result["card_loaded"] = Chadcn::Card.name
  result["card_source"] = Chadcn::Card.instance_method(:view_template).source_location.first.sub(GEM_ROOT, ".")
  # Dialog::Footer (a gem file) builds a Button internally: it must pick up the ejected one.
  # (The root fixture ejects the whole Dialog unit, which here has no Footer.)
  result["footer_uses_ejected_button"] = fixture != "root" && render(Chadcn::Dialog::Footer.new(show_close_button: true)).include?('data-ejected="leaf"')
  result["badge_sees_button"] = Chadcn.const_get(:Button).const_defined?(:EJECTED, false)
  if reload
    override_loader.reload
    gem_loader.reload if reload == "reload"
    result["after_reload_content"] = Chadcn::Dialog::Content.const_defined?(:EJECTED, false) ? Chadcn::Dialog::Content::EJECTED : nil
    result["after_reload_dialog_source"] = Chadcn::Dialog.instance_method(:view_template).source_location&.first.to_s.sub(GEM_ROOT, ".")
    result["after_reload_button"] = Chadcn::Button.const_defined?(:EJECTED, false)
    result["after_reload_footer"] = render(Chadcn::Dialog::Footer.new(show_close_button: true)).include?('data-ejected="leaf"')
  end
rescue StandardError, ScriptError => e
  result["error"] = "#{e.class}: #{e.message[0, 200]}"
end
puts JSON.generate(result)
