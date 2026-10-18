# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "pathname"
require "tempfile"

module Smoke
  # Executes every ```ruby fence of README.md and docs/*.md in one clean child process (no Rails): a fence that defines the README
  # view is rendered through it, the plain-Ruby fence runs as is, every other fence runs inside a Phlex::HTML page. Fences that are
  # not runnable Ruby (Gemfile lines, Rails configuration, a controller) are skipped by content.
  class Docs
    SKIP = [ /\A# Gemfile/, /ApplicationController/, /config\.phlex_shadcn/, /Phlex::Shadcn\.configure/ ].freeze
    # Fences that fail today for a known gem defect. Each must keep failing with its expected error (XFAIL); one that renders fails
    # the run (XPASS), so the PR that fixes the defect also removes its entry here.
    KNOWN_RED = [
      { file: "docs/menus-and-select.md", code: /Phlex::Shadcn::Select\.new/, error: "Nokogiri",
        reason: "Select::Item needs Nokogiri at render time (epic #88)" }
    ].freeze

    def initialize(gem_root)
      @gem_root = Pathname.new(gem_root)
    end

    # @return [Array<Hash>] `{ file:, index:, code:, known_red: }` for every runnable Ruby fence
    def fences
      files = [ "README.md", *Dir.children(@gem_root.join("docs")).grep(/\.md\z/).sort.map { |page| "docs/#{page}" } ]
      files.flat_map do |file|
        File.read(@gem_root.join(file)).scan(/```ruby\n(.*?)```/m).flatten.each_with_index.filter_map do |code, index|
          next if SKIP.any? { |pattern| code.match?(pattern) }

          known = KNOWN_RED.find { |entry| entry[:file] == file && code.match?(entry[:code]) }
          { file: file, index: index, code: code, known_red: known&.slice(:error, :reason) }
        end
      end
    end

    def call
      Tempfile.create([ "phlex-shadcn-doc-fences", ".json" ]) do |file|
        file.write(JSON.generate(fences))
        file.flush
        output, status = Open3.capture2e(RbConfig.ruby, "-I", @gem_root.join("lib").to_s, "-e", RUNNER, file.path)
        [ status.success?, output ]
      end
    end

    # The fences are this gem's own documentation, evaluated on purpose: ruby-gem-conventions R12 forbids eval of caller input.
    RUNNER = <<~'RUBY'
      require "json"
      require "phlex/shadcn"
      Phlex::Shadcn::Loader.eager_load

      module Views; class Base < Phlex::HTML; end; module Demo; end; end
      Invoice = Struct.new(:number, :amount)
      page_class = Class.new(Phlex::HTML) do
        def invoices = [ Invoice.new("INV001", "$250.00") ]
      end

      fences = JSON.parse(File.read(ARGV[0]), symbolize_names: true)
      abort("no runnable documentation fence found") if fences.empty?

      failures = 0
      fences.each do |fence|
        label = "#{fence[:file]} fence #{fence[:index]}"
        known = fence[:known_red]
        begin
          html =
            if fence[:code].match?(/^class Views::/)
              TOPLEVEL_BINDING.eval(fence[:code], label)
              Views::Demo::Index.new.call
            elsif fence[:code].start_with?('require "phlex/shadcn"')
              TOPLEVEL_BINDING.eval(fence[:code], label)
            else
              page = Class.new(page_class)
              page.class_eval("def view_template\n#{fence[:code]}\nend", label, 0)
              page.new.call
            end
          raise "rendered nothing" if html.to_s.strip.empty?

          if known
            failures += 1
            puts "XPASS #{label}: renders now; remove its Smoke::Docs::KNOWN_RED entry (#{known[:reason]})"
          else
            puts "ok    #{label} (#{html.bytesize} bytes)"
          end
        rescue StandardError, ScriptError => e
          detail = "#{e.class}: #{e.message.lines.first&.strip}"
          if known && detail.include?(known[:error])
            puts "XFAIL #{label}: #{known[:reason]}"
          else
            failures += 1
            puts "FAIL  #{label}: #{detail}"
          end
        end
      end
      puts "#{fences.size - failures}/#{fences.size} documentation fences as expected"
      exit(failures.zero? ? 0 : 1)
    RUBY
  end
end
