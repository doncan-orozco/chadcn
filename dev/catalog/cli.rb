# frozen_string_literal: true

# Usage: ruby dev/catalog/cli.rb generate|check [--root DIR]
# --root (default: the gem) is the repository whose scenarios are read and whose entries.json is written or checked.
command = ARGV.shift
root = File.expand_path(ARGV.include?("--root") ? ARGV[ARGV.index("--root") + 1] : File.join(__dir__, "../.."))
$LOAD_PATH.unshift(File.join(root, "lib"))
require "chadcn"
require_relative "generator"

data = Chadcn::CatalogData.new(root)
case command
when "generate"
  data.write
  puts "catalog: wrote #{Chadcn::CatalogData::OUTPUT}"
when "check"
  if data.drifted?
    warn "catalog: #{Chadcn::CatalogData::OUTPUT} drifted from dev/port/scenarios. Run `bundle exec rake catalog:generate` and commit the result."
    exit 1
  end
  puts "catalog: up to date"
else
  abort "usage: ruby dev/catalog/cli.rb generate|check [--root DIR]"
end
