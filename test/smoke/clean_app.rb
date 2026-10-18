# frozen_string_literal: true

require "fileutils"
require "net/http"
require "pathname"
require "socket"
require "tmpdir"
require_relative "readme"

module Smoke
  # Clean-app smoke (ruby-gem-conventions R10, R14): `rails new`, then the README's Rails quick start replayed verbatim (Gemfile
  # lines, `bundle install`, `bin/rails g phlex:shadcn:install`, `bin/rails tailwindcss:build`, the Views::Demo::Index view and its
  # controller), a running server answering with the Button and the Dialog, the built CSS carrying the gem's classes, and one browser
  # scenario (dev/port/scenarios/dialog.json `open__via-trigger-click`, then Escape) driven by Playwright.
  #
  # Needs network (rails new, bundle install), a `rails` executable (SMOKE_RAILS) and node with Playwright (PHLEX_SHADCN_PLAYWRIGHT,
  # or the dev kit's dev/react-shadcn-catalog/node_modules). Never run by `rake test`.
  class CleanApp
    RAILS_NEW_OPTIONS = %w[
      --css tailwind --javascript importmap --skip-git --skip-docker --skip-kamal --skip-ci --skip-solid --skip-active-record
      --skip-active-storage --skip-active-job --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-action-cable
      --skip-jbuilder --skip-test --skip-system-test --skip-rubocop --skip-brakeman --skip-bundler-audit --skip-thruster
      --skip-dev-gems --skip-bootsnap
    ].freeze
    MARKUP = [ 'data-slot="button"', 'data-variant="outline"', 'data-controller="shadcn--dialog"', 'data-slot="dialog-trigger"',
               'data-slot="dialog-content"', '"controllers/shadcn/dialog_controller"' ].freeze
    GEM_LINE = 'gem "phlex-shadcn"'
    DEMO_PATH = "/demo"
    # Arbitrary-value utilities that only the gem's Ruby files use: generated only if an @source line reaches the gem.
    SOURCE_UTILITIES = [ 'ring-\\[3px\\]', 'translate-x-\\[-50\\%\\]' ].freeze
    # Theme variables, token mapping and vendored animations: present only if the generator's theme and engine-bundle imports resolve.
    BUNDLE_MARKERS = [ "--primary", "var(--primary)", "animate-in" ].freeze

    def initialize(gem_root, app_dir: ENV.fetch("SMOKE_APP_DIR", nil), keep: ENV["SMOKE_KEEP"] == "1")
      @gem_root = Pathname.new(gem_root)
      @readme = Readme.new(@gem_root.join("README.md"))
      @app_dir = Pathname.new(app_dir || Dir.mktmpdir("phlex-shadcn-smoke-app-")).expand_path
      @keep = keep || !app_dir.nil?
    end

    def call
      create_app
      follow_the_readme
      serve do |port|
        check_http(port)
        browser_scenario(port)
      end
    ensure
      FileUtils.rm_rf(@app_dir) unless @keep
    end

    private

    def say(message) = puts("smoke --app: #{message}")

    def create_app
      FileUtils.rm_rf(@app_dir)
      FileUtils.mkdir_p(@app_dir.dirname)
      say "rails new #{@app_dir}"
      run(ENV.fetch("SMOKE_RAILS", "rails"), "new", @app_dir.to_s, *RAILS_NEW_OPTIONS, chdir: @app_dir.dirname)
      raise "rails new did not install tailwindcss-rails" unless @app_dir.join("app/assets/tailwind/application.css").file?
    end

    # The Gemfile lines of the README, with the gem taken from this checkout until it is released; then every README command.
    def follow_the_readme
      append_gemfile_lines
      @readme.install_commands.each do |command|
        say command
        run(*command.split, chdir: @app_dir)
        next unless command == "bundle install"

        # README: "`bin/rails g phlex:install` sets up app/views and app/components if you have not done it yet" (needs phlex-rails).
        phlex_rails = @readme.phlex_rails_install_command
        say phlex_rails
        run(*phlex_rails.split, chdir: @app_dir)
      end
      write(@app_dir.join("app/views/demo/index.rb"), @readme.view_source)
      write(@app_dir.join("app/controllers/demo_controller.rb"), @readme.controller_source)
      routes = @app_dir.join("config/routes.rb")
      File.write(routes, File.read(routes).sub(/^end\s*\z/, "  get \"#{DEMO_PATH}\", to: \"demo#index\"\nend\n"))
    end

    def append_gemfile_lines
      lines = @readme.gemfile_lines
      raise "README.md has no #{GEM_LINE} line to point at this checkout; update test/smoke" unless lines.include?(GEM_LINE)

      lines = lines.map { |line| line == GEM_LINE ? %(#{GEM_LINE}, path: #{@gem_root.to_s.inspect}) : line }
      gemfile = @app_dir.join("Gemfile")
      File.write(gemfile, "#{File.read(gemfile).chomp}\n\n# From README.md\n#{lines.join("\n")}\n")
    end

    def serve
      port = free_port
      log = @app_dir.join("log/smoke-server.log")
      FileUtils.mkdir_p(log.dirname)
      FileUtils.rm_f(@app_dir.join("tmp/pids/server.pid")) # a leftover pid file makes `rails server` refuse to start
      say "bin/rails server on port #{port}"
      pid = unbundled do
        Process.spawn({ "RAILS_ENV" => "development" }, "bin/rails", "server", "-p", port.to_s, "-b", "127.0.0.1",
                      chdir: @app_dir.to_s, out: log.to_s, err: log.to_s)
      end
      wait_for_server(port, log)
      yield port
    ensure
      stop(pid) if pid
    end

    # TERM, then KILL after 5 s; a server that already died must not replace the error that stopped the smoke.
    def stop(pid)
      Process.kill("TERM", pid)
      20.times do
        return if Process.wait(pid, Process::WNOHANG)

        sleep 0.25
      end
      Process.kill("KILL", pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def check_http(port)
      body = get(port).body
      missing = MARKUP.reject { |marker| body.include?(marker) }
      raise "GET #{DEMO_PATH} lacks #{missing.join(', ')}:\n#{body}" if missing.any?

      css = File.read(@app_dir.join("app/assets/builds/tailwind.css"))
      unscanned = SOURCE_UTILITIES.reject { |marker| css.include?(marker) }
      raise "the Tailwind build lacks #{unscanned.join(', ')}: no @source line reached the gem's Ruby files" if unscanned.any?

      unimported = BUNDLE_MARKERS.reject { |marker| css.include?(marker) }
      raise "the Tailwind build lacks #{unimported.join(', ')}: the theme or engine-bundle import did not resolve" if unimported.any?

      say "GET #{DEMO_PATH} renders the Button and the Dialog; the Tailwind build contains the gem's classes"
    end

    def browser_scenario(port)
      say "browser scenario open__via-trigger-click + Escape"
      run("node", @gem_root.join("test/smoke/app/dialog_scenario.mjs").to_s, "http://127.0.0.1:#{port}#{DEMO_PATH}", chdir: @gem_root)
    end

    def get(port)
      response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}#{DEMO_PATH}"))
      raise "GET #{DEMO_PATH} answered #{response.code}:\n#{response.body}" unless response.code == "200"

      response
    end

    def wait_for_server(port, log)
      60.times do
        TCPSocket.new("127.0.0.1", port).close
        return
      rescue Errno::ECONNREFUSED
        sleep 0.5
      end
      raise "the server did not start:\n#{File.read(log)}"
    end

    def free_port
      server = TCPServer.new("127.0.0.1", 0)
      server.addr[1]
    ensure
      server&.close
    end

    def write(path, source)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, source)
    end

    # Commands of the generated app run outside this process' bundle (its own Gemfile, its own gems).
    def run(*command, chdir:)
      success = unbundled { system(*command, chdir: chdir.to_s) }
      raise "command failed (#{command.join(' ')}) in #{chdir}" unless success
    end

    def unbundled(&)
      defined?(Bundler) ? Bundler.with_unbundled_env(&) : yield
    end
  end
end
