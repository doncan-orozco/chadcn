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
      --skip-git --skip-docker --skip-kamal --skip-ci --skip-solid --skip-active-record
      --skip-active-storage --skip-active-job --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-action-cable
      --skip-jbuilder --skip-test --skip-system-test --skip-rubocop --skip-brakeman --skip-bundler-audit --skip-thruster
      --skip-dev-gems --skip-bootsnap
    ].freeze
    MARKUP = [ 'data-slot="button"', 'data-variant="outline"', 'data-controller="shadcn--dialog"', 'data-slot="dialog-trigger"',
               'data-slot="dialog-content"', '"controllers/shadcn/dialog_controller"' ].freeze
    # esbuild apps have no importmap: the controller registration is bundled into app/assets/builds/application.js instead.
    ESBUILD_MARKUP = MARKUP.first(5).freeze
    ESBUILD_BUNDLE_MARKERS = [ "shadcn--dialog", "shadcn--dropdown-menu", "computePosition" ].freeze
    GEM_LINE = 'gem "phlex-shadcn"'
    DEMO_PATH = "/demo"
    # Arbitrary-value utilities that only the gem's Ruby files use: generated only if an @source line reaches the gem.
    SOURCE_UTILITIES = [ 'ring-\\[3px\\]', 'translate-x-\\[-50\\%\\]' ].freeze
    # Theme variables, token mapping and vendored animations: present only if the generator's theme and engine-bundle imports resolve.
    BUNDLE_MARKERS = [ "--primary", "var(--primary)", "animate-in" ].freeze

    # Rails 8.1's `rails new` only offers Propshaft; a Sprockets app is the same app with sprockets-rails, a manifest.js and the
    # importmap/Tailwind installers, as an upgraded Rails 7 app has it (dev/decisions/sprockets.md).
    SPROCKETS_GEMS = %w[sprockets-rails importmap-rails turbo-rails stimulus-rails tailwindcss-rails].freeze
    SPROCKETS_MANIFEST = <<~JS
      //= link_tree ../images
      //= link_directory ../stylesheets .css
      //= link_tree ../builds
      //= link_tree ../../javascript .js
    JS
    SPROCKETS_RAILS_NEW_OPTIONS = %w[--skip-asset-pipeline --skip-javascript].freeze

    def initialize(gem_root, javascript: "importmap", assets: "propshaft", app_dir: ENV.fetch("SMOKE_APP_DIR", nil),
                   keep: ENV["SMOKE_KEEP"] == "1")
      @javascript = javascript
      @assets = assets
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
      run(ENV.fetch("SMOKE_RAILS", "rails"), "new", @app_dir.to_s, *RAILS_NEW_OPTIONS, *rails_new_pipeline_options, chdir: @app_dir.dirname)
      install_tailwindcss_rails if esbuild?
      install_sprockets if sprockets?
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
      build_javascript if esbuild?
      run_doctor
      precompile_assets if sprockets?
      write(@app_dir.join("app/views/demo/index.rb"), @readme.view_source)
      write(@app_dir.join("app/controllers/demo_controller.rb"), @readme.controller_source)
      routes = @app_dir.join("config/routes.rb")
      File.write(routes, File.read(routes).sub(/^end\s*\z/, "  get \"#{DEMO_PATH}\", to: \"demo#index\"\nend\n"))
    end

    # `rails new --css tailwind` on a bundler app picks the node Tailwind CLI; the gem needs tailwindcss-rails, so an esbuild app adds it the way
    # the README asks ("tailwindcss-rails installed already").
    def rails_new_pipeline_options
      return SPROCKETS_RAILS_NEW_OPTIONS if sprockets?

      esbuild? ? %w[--javascript esbuild] : %w[--css tailwind --javascript importmap]
    end

    # Sprockets + importmap + Tailwind, installed the way each gem documents it for an app that was not generated with them.
    def install_sprockets
      raise "the sprockets smoke supports importmap only" if esbuild?

      say "sprockets-rails, importmap, turbo, stimulus and tailwindcss-rails installers"
      run("bundle", "add", *SPROCKETS_GEMS, chdir: @app_dir)
      write(@app_dir.join("app/assets/config/manifest.js"), SPROCKETS_MANIFEST)
      FileUtils.mkdir_p(@app_dir.join("app/assets/builds"))
      FileUtils.touch(@app_dir.join("app/assets/builds/.keep"))
      %w[importmap:install turbo:install stimulus:install tailwindcss:install].each { |task| run("bin/rails", task, chdir: @app_dir) }
    end

    def install_tailwindcss_rails
      say "bundle add tailwindcss-rails && bin/rails tailwindcss:install"
      run("bundle", "add", "tailwindcss-rails", chdir: @app_dir)
      run("bin/rails", "tailwindcss:install", chdir: @app_dir)
    end

    # The doctor exits 1 on any failed check: it must accept what the README's steps produced, in either pipeline.
    def run_doctor
      say "bin/rails phlex_shadcn:doctor"
      run("bin/rails", "phlex_shadcn:doctor", chdir: @app_dir)
      return unless sprockets?

      # Warnings do not fail the doctor: the Sprockets app has to pass its pipeline check.
      output = unbundled { IO.popen([ "bin/rails", "phlex_shadcn:doctor" ], chdir: @app_dir.to_s, err: %i[child out], &:read) }
      raise "the doctor does not pass the asset pipeline check:\n#{output}" unless output.include?("[PASS] asset pipeline: Sprockets")
    end

    # Production build: every declared asset (the gem's JavaScript included) compiles and gets a digest in public/assets.
    def precompile_assets
      say "RAILS_ENV=production bin/rails assets:precompile"
      success = unbundled { system({ "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1" }, "bin/rails", "assets:precompile", chdir: @app_dir.to_s) }
      raise "assets:precompile failed" unless success

      compiled = Dir[@app_dir.join("public/assets/controllers/shadcn/dialog_controller-*.js").to_s]
      raise "assets:precompile did not compile the gem's dialog controller" if compiled.empty?

      # The development server must serve from Sprockets, not from the built files in public/assets (assets:clobber would also delete
      # the Tailwind build).
      FileUtils.rm_rf(@app_dir.join("public/assets"))
    end

    def esbuild? = @javascript == "esbuild"

    def sprockets? = @assets == "sprockets"

    # The pipeline's own build (what bin/dev's Procfile runs in watch mode): bundles the copied controllers into builds/application.js.
    def build_javascript
      say "bin/rails javascript:build"
      run("bin/rails", "javascript:build", chdir: @app_dir)
      bundle = @app_dir.join("app/assets/builds/application.js").read
      missing = ESBUILD_BUNDLE_MARKERS.reject { |marker| bundle.include?(marker) }
      raise "the esbuild bundle lacks #{missing.join(', ')}: the copied controllers were not bundled" if missing.any?
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
      missing = (esbuild? ? ESBUILD_MARKUP : MARKUP).reject { |marker| body.include?(marker) }
      raise "GET #{DEMO_PATH} lacks #{missing.join(', ')}:\n#{body}" if missing.any?

      check_served_assets(port, body)
      css = File.read(@app_dir.join("app/assets/builds/tailwind.css"))
      unscanned = SOURCE_UTILITIES.reject { |marker| css.include?(marker) }
      raise "the Tailwind build lacks #{unscanned.join(', ')}: no @source line reached the gem's Ruby files" if unscanned.any?

      unimported = BUNDLE_MARKERS.reject { |marker| css.include?(marker) }
      raise "the Tailwind build lacks #{unimported.join(', ')}: the theme or engine-bundle import did not resolve" if unimported.any?

      say "GET #{DEMO_PATH} renders the Button and the Dialog; the Tailwind build contains the gem's classes"
    end

    # Every stylesheet and module the page links answers 200: Sprockets refuses (or 404s) assets that were not declared precompiled.
    def check_served_assets(port, body)
      urls = body.scan(%r{(?:href|src)="(/assets/[^"]+)"}).flatten.uniq
      urls += body.scan(%r{"(/assets/[^"]+\.js)"}).flatten
      urls.uniq!
      raise "GET #{DEMO_PATH} links no /assets file:\n#{body}" if urls.empty?

      broken = urls.reject { |url| Net::HTTP.get_response(URI("http://127.0.0.1:#{port}#{url}")).code == "200" }
      raise "these linked assets are not served: #{broken.join(', ')}" if broken.any?

      say "#{urls.size} linked assets answer 200"
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
