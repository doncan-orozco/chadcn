#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate G5 (house), mechanical part: library-wide consistency. No browser, no LLM.
#   ruby .claude/scripts/shadcn/house_check.rb [--static-all]
# --static-all additionally runs the G1 static gate for every component whose state is `done`.
# Exit 1 when any finding exists. Prints JSON { pass, findings: [{ code, detail }] }.

require_relative "layout"
require "json"
require "open3"
require "optparse"

opts = {}
OptionParser.new { |o| o.on("--static-all") { opts[:static_all] = true } }.parse!

findings = []
add = ->(code, detail) { findings << { code: code, detail: detail } }

state_file = ShadcnLayout::STATE_FILE
state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : abort("no #{state_file}")
done = state["components"].select { |n, c| c["status"] == "done" && !n.start_with?("_") }.keys

# A done library without its JS directories means a wrong SHADCN_* override or a layout that has not landed yet: every controller check
# below would be meaningless, so report that once instead of a false red per component or a silent pass.
js_dirs = [ShadcnLayout::CONTROLLER_DIR, ShadcnLayout::PRIMITIVES_DIR]
js_layout_missing = done.any? && js_dirs.none? { |dir| Dir.exist?(dir) }
add.call("G5_LAYOUT_MISSING", "#{js_dirs.join(', ')} missing (check SHADCN_CONTROLLER_DIR / SHADCN_PRIMITIVES_DIR)") if js_layout_missing

done.each do |name|
  manifest = JSON.parse(File.read("#{ShadcnLayout::ORACLE_DIR}/manifest/#{name}.json"))
  ruby_name = ShadcnLayout.ruby_name(name)
  ruby_file = File.join(ShadcnLayout::RUBY_DIR, "#{ruby_name}.rb")
  add.call("G5_FILE_MISSING", ruby_file) unless File.exist?(ruby_file)
  add.call("G5_SPEC_MISSING", "#{ShadcnLayout::SPECS_DIR}/#{name}.md") unless File.exist?("#{ShadcnLayout::SPECS_DIR}/#{name}.md")
  add.call("G5_SCENARIOS_MISSING", "#{ShadcnLayout::SCENARIOS_DIR}/#{name}.json") unless File.exist?("#{ShadcnLayout::SCENARIOS_DIR}/#{name}.json")
  interactive = manifest["tier"] != "static"
  controller = ShadcnLayout.controller_file(name)
  # A spec may state that no controller is written on purpose (radix-stimulus R11: attaching one adds DOM the oracle lacks).
  spec = File.exist?("#{ShadcnLayout::SPECS_DIR}/#{name}.md") ? File.read("#{ShadcnLayout::SPECS_DIR}/#{name}.md") : ""
  no_controller = spec.match?(/No Stimulus controller|no `#{Regexp.escape(ShadcnLayout.identifier(name))}` controller|There is no `#{Regexp.escape(ShadcnLayout.identifier(name))}` controller/i)
  add.call("G5_CONTROLLER_MISSING", controller) if !js_layout_missing && interactive && !File.exist?(controller) && manifest["tier"] != "client" && !no_controller
  if opts[:static_all]
    out, = Open3.capture2("ruby", ".claude/scripts/shadcn/static_gate.rb", "--component", name)
    add.call("G5_REGRESSION_G1", name) unless JSON.parse(out)["pass"]
  end
end

# Orphan controllers: a ui controller without a component in the manifest set (base/theme helpers excepted).
known = Dir["#{ShadcnLayout::ORACLE_DIR}/manifest/*.json"].map { |f| ShadcnLayout.ruby_name(File.basename(f, ".json")) }
# The packaged controller tree holds components only: a controller without a component in the manifest set is an orphan (base/theme helpers
# excepted); a probe or the theme panel there would ship to every consumer (G5_DEV_CONTROLLER_PACKAGED).
Dir[File.join(ShadcnLayout::CONTROLLER_DIR, "*_controller.js")].each do |f|
  base = File.basename(f, "_controller.js")
  next if known.include?(base) || %w[base theme].include?(base)

  dev_only = base.start_with?("_probe_") || base == "theme_panel"
  add.call(dev_only ? "G5_DEV_CONTROLLER_PACKAGED" : "G5_ORPHAN_CONTROLLER", f)
end
# Dev-only controllers live in the dummy app: theme_panel (harness) and _probe_<name> test controllers that have a react twin whose
# `probe.controller` is chadcn---probe-<name>.
probe_ids = Dir["#{ShadcnLayout::CATALOG_DIR}/src/parity/primitives/*.tsx"].filter_map { |f| File.read(f)[/controller:\s*"(#{Regexp.escape(ShadcnLayout::STIMULUS_PREFIX)}---probe-[^"]+)"/, 1] }
Dir[File.join(ShadcnLayout::PROBE_DIR, "*_controller.js")].each do |f|
  base = File.basename(f, "_controller.js")
  next if base == "theme_panel"
  next if base.start_with?("_probe_") && probe_ids.include?("#{ShadcnLayout::STIMULUS_PREFIX}---probe-#{base.delete_prefix('_probe_').tr('_', '-')}")

  add.call("G5_ORPHAN_CONTROLLER", f)
end

# Deviations register must list every deviations file, and vice versa.
register = File.exist?(ShadcnLayout::DEVIATIONS_REGISTER) ? File.read(ShadcnLayout::DEVIATIONS_REGISTER) : ""
Dir["#{ShadcnLayout::DEVIATIONS_DIR}/*.json"].each do |f|
  name = File.basename(f, ".json")
  add.call("G5_DEVIATION_UNREGISTERED", name) unless register.include?("`#{name}`")
end

if File.exist?("#{ShadcnLayout::CATALOG_DIR}/node_modules/tailwind-merge/package.json") && Dir.exist?("#{ShadcnLayout::ORACLE_DIR}/src")
  out, status = Open3.capture2("ruby", ".claude/scripts/shadcn/cn_differential.rb", "--show", "3")
  summary = (JSON.parse(out) rescue {}).slice("js_version", "ruby_version", "mismatch_count", "classes_that_differ")
  add.call("G5_CN_DIFFERENTIAL", "oracle cn (JS twMerge) and port cn (Ruby tailwind_merge) disagree: #{summary}") unless status.success?
end

if Dir.exist?(ShadcnLayout::SPECS_DIR) && Dir.exist?("#{ShadcnLayout::ORACLE_DIR}/manifest")
  out, = Open3.capture2("ruby", ".claude/scripts/shadcn/spec_helpers.rb", "--all", "--check")
  stale = (JSON.parse(out)["stale"] rescue [])
  add.call("G5_SPEC_HELPERS", "specs without a current DX helpers section (run spec_helpers.rb --all): #{stale.first(8).join(', ')}") if stale.any?
end

catalog_css = "#{ShadcnLayout::CATALOG_DIR}/src/index.css"
if File.exist?(catalog_css) && File.read(catalog_css).match?(/^\s*(:root|\.dark)\b|@theme/)
  add.call("G5_CATALOG_CSS", "#{catalog_css} must only import tailwindcss, tw-animate-css and the host theme (the shadcn CLI appends HSL variables)")
end

importmap_file = "#{ShadcnLayout::GEM_DIR}/config/importmap.rb"
importmap = File.exist?(importmap_file) ? File.read(importmap_file) : ""
catalog_fui = "#{ShadcnLayout::CATALOG_DIR}/node_modules/@floating-ui/dom/package.json"
if File.exist?(catalog_fui) && (pinned = importmap[/pin "@floating-ui\/dom".*?# @([\d.]+)/, 1])
  catalog_version = JSON.parse(File.read(catalog_fui))["version"]
  add.call("G5_FLOATING_UI_VERSION", "importmap pins @floating-ui/dom #{pinned} but the catalog (oracle) runs #{catalog_version}: re-pin") unless pinned == catalog_version
end
[File.dirname(ShadcnLayout::PRIMITIVES_DIR), ShadcnLayout::CONTROLLER_DIR].each do |dir|
  next unless Dir.exist?(dir)
  relative = dir.delete_prefix("#{ShadcnLayout::GEM_DIR}/")
  next if importmap.match?(/^\s*pin_all_from\s+File\.expand_path\(["']\.\.\/#{Regexp.escape(relative)}["'],\s*__dir__\)/)

  add.call("G5_IMPORTMAP", "#{importmap_file} lacks pin_all_from File.expand_path(\"../#{relative}\", __dir__)")
end

# G5 validates the gem's default theme; the host's theme.css is validated by `bin/rails theme:check` and the engine integration test.
require File.expand_path("lib/chadcn/theme", ShadcnLayout::GEM_DIR)
if File.exist?("#{ShadcnLayout::THEME_DIR}/theme.css")
  theme = Chadcn::Theme.validate(Chadcn::Theme.parse(File.read("#{ShadcnLayout::THEME_DIR}/theme.css")))
  theme[:errors].each { |e| add.call("G5_THEME_INVALID", e) }
  if File.exist?("#{ShadcnLayout::THEME_DIR}/tokens.css") && Dir.exist?("#{ShadcnLayout::ORACLE_DIR}/manifest")
    out, status = Open3.capture2("ruby", ".claude/scripts/shadcn/theme_sync.rb", "--check-tokens")
    add.call("G5_TOKENS_DRIFT", out.strip[0, 400]) unless status.success?
  end
else
  add.call("G5_THEME_MISSING", "#{ShadcnLayout::THEME_DIR}/theme.css")
end

puts JSON.pretty_generate(pass: findings.empty?, components_checked: done.size, findings: findings)
exit(findings.empty? ? 0 : 1)
