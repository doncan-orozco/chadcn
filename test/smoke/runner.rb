# frozen_string_literal: true

require_relative "plain"
require_relative "docs"
require_relative "clean_app"

module Smoke
  # Entry point of bin/smoke: one mode per flag, exit status 0 when it passes.
  module Runner
    USAGE = <<~TEXT
      usage: bin/smoke --plain | --docs | --app
        --plain  Rails-free process renders the README's plain-Ruby fence and its Button + Dialog view (offline)
        --docs   every ```ruby fence of README.md and docs/*.md renders in a plain process (offline)
        --app    rails new, the README quick start verbatim, HTTP checks and one Playwright dialog scenario (network, browser)
    TEXT

    def self.call(argv, gem_root: File.expand_path("../..", __dir__))
      case argv
      when [ "--plain" ]
        result = Plain.new(gem_root).call
        puts result.output
        result.success? ? 0 : 1
      when [ "--docs" ]
        success, output = Docs.new(gem_root).call
        puts output
        success ? 0 : 1
      when [ "--app" ]
        CleanApp.new(gem_root).call
        puts "smoke --app: ok"
        0
      else
        warn USAGE
        2
      end
    end
  end
end
