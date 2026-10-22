#!/usr/bin/env ruby
# frozen_string_literal: true

# Makes sure the React catalog has a Playwright that can actually LAUNCH a browser on this machine, because parity_run.mjs
# resolves `playwright` from the React catalog (layout.rb CATALOG_DIR) and a newest-version install wants a Chromium build you may not have.
#
#   ruby .claude/scripts/shadcn/playwright_ensure.rb            # install if missing, then smoke test; exit 1 when no browser works
#   ruby .claude/scripts/shadcn/playwright_ensure.rb --check    # smoke test only
#
# Strategy: (1) already launches? done. (2) pick the playwright version whose Chromium revision is already in the cache
# (no download), (3) otherwise install the latest and `npx playwright install chromium`.
# Prints JSON { playwright:, chromium:, launched: } .

require_relative "layout"
require "json"
require "open3"
require "optparse"

CATALOG = ShadcnLayout::CATALOG_DIR
# Chromium revision -> the playwright release that uses it (from each release's playwright-core/browsers.json).
REVISION_TO_VERSION = { "1194" => "1.56.0", "1200" => "1.57.0", "1208" => "1.58.0", "1217" => "1.59.0", "1223" => "1.60.0", "1228" => "1.61.0", "1234" => "1.62.0" }.freeze
CACHE = File.expand_path(ENV.fetch("PLAYWRIGHT_BROWSERS_PATH", "~/Library/Caches/ms-playwright"))
SMOKE = <<~JS
  const { chromium } = require("playwright");
  (async () => {
    const b = await chromium.launch();
    const p = await b.newPage();
    await p.setContent('<button id="x" onclick="this.dataset.ok=1">hi</button>');
    await p.click("#x");
    console.log(JSON.stringify({ version: b.version(), click: await p.getAttribute("#x", "data-ok") }));
    await b.close();
  })().catch((e) => { console.error(String(e).split("\\n")[0]); process.exit(1); });
JS

opts = { check: false }
OptionParser.new { |o| o.on("--check") { opts[:check] = true } }.parse!

def smoke
  out, err, st = Open3.capture3("node", "-e", SMOKE, chdir: CATALOG)
  st.success? ? [JSON.parse(out), nil] : [nil, err.lines.first.to_s.strip]
end

def installed_version
  JSON.parse(File.read(File.join(CATALOG, "node_modules/playwright/package.json")))["version"]
rescue Errno::ENOENT
  nil
end

abort("no #{CATALOG}/ (run /shadcn-plan first)") unless File.directory?(CATALOG)
result, error = smoke
unless result || opts[:check]
  cached = Dir[File.join(CACHE, "chromium-*")].map { |d| File.basename(d)[/\d+/] }.sort_by(&:to_i).reverse
  version = cached.filter_map { |rev| REVISION_TO_VERSION[rev] }.first
  warn "installing playwright@#{version || 'latest'} into #{CATALOG} (#{version ? 'matches the cached Chromium, no download' : 'no cached Chromium known: will download one'})"
  system("npm", "i", "-D", "--no-audit", "--no-fund", "playwright@#{version || 'latest'}", chdir: CATALOG, exception: true)
  result, error = smoke
  unless result
    warn "launch failed (#{error}); downloading Chromium with `npx playwright install chromium`"
    system("npx", "playwright", "install", "chromium", chdir: CATALOG, exception: true)
    result, error = smoke
  end
end

puts JSON.pretty_generate(playwright: installed_version, chromium: result&.fetch("version"), launched: !result.nil?, error: error)
exit(result ? 0 : 1)
