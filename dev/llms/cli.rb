# frozen_string_literal: true

# Usage: ruby dev/llms/cli.rb generate|check [--root DIR]
# The lib/ and app/ of --root (default: the gem) are what gets documented, so a test can mutate a copy and prove that `check` fails.
require "fileutils"

command = ARGV.shift
root = File.expand_path(ARGV.include?("--root") ? ARGV[ARGV.index("--root") + 1] : File.join(__dir__, "../.."))
$LOAD_PATH.unshift(File.join(root, "lib"))
require "chadcn"
require_relative "generator"

case command
when "generate"
  Chadcn::Llms.write(root)
  puts "llms: wrote #{Chadcn::Llms::OUTPUTS.join(', ')}"
when "check"
  drifted = Chadcn::Llms.drift(root)
  if drifted.empty?
    puts "llms: up to date"
  else
    warn "llms: #{drifted.join(', ')} drifted from the code. Run `bundle exec rake llms:generate` and commit the result."
    exit 1
  end
else
  abort "usage: ruby dev/llms/cli.rb generate|check [--root DIR]"
end
