#!/usr/bin/env ruby
# frozen_string_literal: true

# Differential test of the class merger: the oracle's `cn` is clsx + JS `twMerge`, the port's `cn` is the Ruby
# `tailwind_merge` gem. The DOM class sets compared by G2 come out of these mergers, so they must agree on real shadcn vocabulary.
#
#   ruby .claude/scripts/shadcn/cn_differential.rb [--oracle DIR] [--js-dir <catalog dir>] [--max-pairs-per-component 3000]
#
# Corpus: every multi-token string literal in the oracle sources (cva bases, variants, cn(...) arguments, className props),
# per component. For each component all ordered pairs `"a b"` are merged on both sides (plus each string alone).
# Prints JSON { pass, js_version, ruby_version, strings, merges, mismatches: [...] }; exit 1 on any mismatch.

require_relative "layout"
require "json"
require "open3"
require "optparse"
require "tmpdir"
require "tailwind_merge"

opts = { oracle: ShadcnLayout::ORACLE_DIR, js_dir: ShadcnLayout::CATALOG_DIR, cap: 3000, show: 15 }
OptionParser.new do |o|
  o.on("--oracle DIR") { |v| opts[:oracle] = v }
  o.on("--js-dir DIR") { |v| opts[:js_dir] = v }
  o.on("--max-pairs-per-component N", Integer) { |v| opts[:cap] = v }
  o.on("--show N", Integer) { |v| opts[:show] = v }
end.parse!

js_pkg = File.join(opts[:js_dir], "node_modules/tailwind-merge/package.json")
abort("tailwind-merge not installed in #{opts[:js_dir]}/node_modules") unless File.exist?(js_pkg)

corpus = Dir[File.join(opts[:oracle], "src/*.tsx")].sort.to_h do |file|
  strings = File.read(file).scan(/"((?:[^"\\]|\\.)*)"|`((?:[^`\\]|\\.)*)`/).map { |m| m.compact.first }
                .reject { |s| s.include?("${") || s.include?("\n") }
                .select { |s| s.split(/\s+/).size >= 2 && s.match?(/[a-z]-|\[|:/) && !s.match?(/\A(use client|import|export)/) }
                .uniq
  [File.basename(file, ".tsx"), strings]
end

inputs = corpus.flat_map do |_, strings|
  pairs = strings.product(strings).map { |a, b| "#{a} #{b}" }
  pairs = pairs.first(opts[:cap]) if pairs.size > opts[:cap]
  strings + pairs
end.uniq

js_script = <<~JS
  const { twMerge } = require(process.argv[1]);
  const inputs = JSON.parse(require("fs").readFileSync(0, "utf8"));
  process.stdout.write(JSON.stringify(inputs.map((s) => twMerge(s))));
JS
js_out, js_err, js_status = Open3.capture3("node", "-e", js_script, File.expand_path(File.join(opts[:js_dir], "node_modules/tailwind-merge")), stdin_data: JSON.generate(inputs))
abort("node failed: #{js_err.lines.first}") unless js_status.success?
js = JSON.parse(js_out)

merger = TailwindMerge::Merger.new
mismatches = inputs.each_with_index.filter_map do |input, i|
  ruby = merger.merge(input)
  next if ruby.split.sort == js[i].split.sort # compare as class SETS (what G2 compares); order differences are reported separately below

  { input: input, js: js[i], ruby: ruby }
end
order_only = inputs.each_with_index.count { |input, i| merger.merge(input) != js[i] && merger.merge(input).split.sort == js[i].split.sort }

# Which classes are involved, to make the report actionable.
culprits = mismatches.flat_map { |m| (j = m[:js].split; r = m[:ruby].split; (j | r) - (j & r)) }.tally.sort_by { |_, n| -n }.first(12).to_h

puts JSON.pretty_generate(
  pass: mismatches.empty?,
  js_version: JSON.parse(File.read(js_pkg))["version"],
  ruby_version: Gem.loaded_specs["tailwind_merge"]&.version.to_s,
  strings: corpus.values.sum(&:size),
  merges: inputs.size,
  mismatch_count: mismatches.size,
  order_only_differences: order_only,
  classes_that_differ: culprits,
  examples: mismatches.first(opts[:show])
)
exit(mismatches.empty? ? 0 : 1)
