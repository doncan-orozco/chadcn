# frozen_string_literal: true

module Smoke
  # The README is the first test (ruby-gem-conventions R14): the smoke replays its code fences instead of copying them, so a README
  # that drifts from the code fails here. Fences are picked by their content, not by position.
  class Readme
    FENCE = /```(\w+)\n(.*?)```/m

    def initialize(path)
      @path = path
      @text = File.read(path)
    end

    # @return [Array<Hash>] every fenced block: `{ lang:, code: }`
    def fences
      @fences ||= @text.scan(FENCE).map { |lang, code| { lang: lang, code: code } }
    end

    # The shell steps of the Rails quick start, in order (`bundle install`, the install generator, the Tailwind build).
    def install_commands
      fence(:bash) { |code| code.include?("phlex:shadcn:install") }.lines.map(&:strip).reject(&:empty?)
    end

    # The Gemfile lines of the Rails quick start (comments dropped).
    def gemfile_lines
      fence(:ruby) { |code| code.start_with?("# Gemfile") }.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end

    # The Phlex view that renders a Button and a Dialog.
    def view_source = fence(:ruby) { |code| code.include?("class Views::Demo::Index") }

    # The controller that renders that view.
    def controller_source = fence(:ruby) { |code| code.include?("class DemoController") }

    # The plain-Ruby usage (no Rails).
    def without_rails_source = fence(:ruby) { |code| code.start_with?('require "phlex/shadcn"') }

    # The phlex-rails setup step the quick start names inline ("`bin/rails g phlex:install` sets up app/views ...").
    def phlex_rails_install_command
      @text[%r{`(bin/rails g phlex:install)`}, 1] or
        raise "#{@path}: the quick start no longer names `bin/rails g phlex:install`; update test/smoke"
    end

    private

    def fence(lang)
      matches = fences.select { |candidate| candidate[:lang] == lang.to_s && yield(candidate[:code]) }
      raise "#{@path}: #{matches.size} #{lang} fences matched, expected exactly 1; the README changed shape, update test/smoke" unless matches.size == 1

      matches.first[:code]
    end
  end
end
