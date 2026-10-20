# frozen_string_literal: true

require_relative "plain"
require_relative "docs"
require_relative "clean_app"

module Smoke
  # Entry point of bin/smoke: one mode per flag, exit status 0 when it passes.
  module Runner
    USAGE = <<~TEXT
      usage: bin/smoke --plain | --docs | --app [--js importmap|esbuild | --assets propshaft|sprockets]
        --plain  Rails-free process renders the README's plain-Ruby fence and its Button + Dialog view (offline)
        --docs   every ```ruby fence of README.md and docs/*.md renders in a plain process (offline)
        --app    rails new, the README quick start verbatim, HTTP checks and one Playwright dialog scenario (network, browser)
        --js     with --app: the app's JavaScript pipeline, importmap (default) or esbuild (jsbundling-rails; copies the gem's JavaScript)
        --assets with --app: the asset pipeline, propshaft (default) or sprockets (sprockets-rails with importmap; Rails 8.1's `rails new`
                 no longer offers it, so the smoke adds it, see dev/decisions/sprockets.md)
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
      when [ "--app" ], [ "--app", "--js", "importmap" ], [ "--app", "--js", "esbuild" ],
           [ "--app", "--assets", "propshaft" ], [ "--app", "--assets", "sprockets" ]
        options = argv[1..].each_slice(2).to_h
        CleanApp.new(gem_root, javascript: options.fetch("--js", "importmap"), assets: options.fetch("--assets", "propshaft")).call
        puts "smoke --app: ok"
        0
      else
        warn USAGE
        2
      end
    end
  end
end
