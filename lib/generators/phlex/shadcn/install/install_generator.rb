# frozen_string_literal: true

require "rails/generators"
require "pathname"
require "phlex/shadcn"

module Phlex
  module Shadcn
    # Rails generators of the gem (`rails g phlex:shadcn:install`).
    module Generators
      # `rails g phlex:shadcn:install` wires the gem into a host that uses tailwindcss-rails:
      #
      # 1. writes one marker-delimited block into the Tailwind entry file (app/assets/tailwind/application.css) right after
      #    `@import "tailwindcss";`: the `@source` line for the gem's Ruby files (Tailwind 4 only generates the classes it finds in
      #    scanned files, so without it the components render unstyled), the import of the engine bundle and of the theme file;
      # 2. copies the default theme (theme.css and presets/) into the host's theme directory unless they already exist.
      #
      # It is idempotent: a second run rewrites the same block and skips the existing theme files, so nothing changes. The block is
      # managed by the generator; edits inside the markers are overwritten. (The engine's own CSS also carries a relative `@source`,
      # regenerated on every tailwindcss:build, so a gem update that moves the absolute path in this block cannot unstyle the app.)
      #
      # @api private
      class InstallGenerator < ::Rails::Generators::Base
        desc "Imports the phlex-shadcn Tailwind assets (with the @source line for the gem) and copies the default theme."

        source_root Phlex::Shadcn.root.join("app/assets/tailwind/phlex-shadcn").to_s

        class_option :css, type: :string, default: "app/assets/tailwind/application.css",
                           desc: "The Tailwind entry file of the app"
        class_option :theme_dir, type: :string,
                                 desc: "Where theme.css and presets/ are kept (default: config.phlex_shadcn.theme_dir, " \
                                       "else #{Phlex::Shadcn::Engine::DEFAULT_THEME_DIR})"

        BLOCK_START = "/* phlex-shadcn:start (managed by rails g phlex:shadcn:install) */"
        BLOCK_END = "/* phlex-shadcn:end */"
        # `@import "tailwindcss";` also with options such as `source(none)` or `prefix(tw)`, LF or CRLF.
        TAILWIND_IMPORT = /^@import\s+["']tailwindcss["'][^;\n]*;[ \t]*(?=\r?$)/
        MANAGED_BLOCK = /#{Regexp.escape(BLOCK_START)}.*?#{Regexp.escape(BLOCK_END)}/m
        ENGINE_BUNDLE = "app/assets/builds/tailwind/phlex-shadcn"
        private_constant :BLOCK_START, :BLOCK_END, :TAILWIND_IMPORT, :MANAGED_BLOCK, :ENGINE_BUNDLE

        # Scripted installs (CI, smoke tests) must see a failure: Rails generators exit 0 on Thor::Error unless this is true.
        def self.exit_on_failure? = true

        def check_entry_file
          return if File.file?(css_path)

          raise Thor::Error, "#{options[:css]} not found: install tailwindcss-rails first (bin/rails tailwindcss:install)"
        end

        def write_css_block
          original = File.binread(css_path).force_encoding(Encoding::UTF_8)
          updated = with_block(original)
          return say_status(:identical, options[:css], :blue) if updated == original

          File.binwrite(css_path, updated) unless options[:pretend]
          say_status(original.include?(BLOCK_START) ? :update : :insert, options[:css], :green)
        end

        def copy_default_theme
          copy_file "theme.css", File.join(theme_dir, "theme.css"), skip: true
          directory "presets", File.join(theme_dir, "presets"), skip: true
        end

        def show_next_steps
          say "\nRun bin/rails tailwindcss:build (it bundles the engine CSS) and restart the server.", :green
          return if theme_dir == (configured_theme_dir || Phlex::Shadcn::Engine::DEFAULT_THEME_DIR)

          say "The theme tasks look in #{configured_theme_dir || Phlex::Shadcn::Engine::DEFAULT_THEME_DIR}: set " \
              "config.phlex_shadcn.theme_dir = \"#{theme_dir}\" in config/application.rb.", :yellow
        end

        private

        def css_path = File.expand_path(options[:css], destination_root)

        def configured_theme_dir = ::Rails.application&.config&.phlex_shadcn&.theme_dir # rubocop:disable Style/SafeNavigationChainLength

        def theme_dir = options[:theme_dir] || configured_theme_dir || Phlex::Shadcn::Engine::DEFAULT_THEME_DIR

        def theme_path = File.expand_path(File.join(theme_dir, "theme.css"), destination_root)

        def relative_to_css(path)
          Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(css_path).dirname).to_s
        rescue ::ArgumentError => e # Phlex::ArgumentError would win the constant lookup here
          raise Thor::Error, "cannot express #{path} relative to #{options[:css]} (#{e.message}): after @import \"tailwindcss\"; add an @source for " \
                             "#{File.join(Phlex::Shadcn.root.to_s, 'lib')} and @imports of #{ENGINE_BUNDLE} and #{theme_dir}/theme.css"
        end

        # With `eol` the block uses the file's own line endings (CRLF files stay consistent).
        def managed_block(eol)
          source = relative_to_css(Phlex::Shadcn.root.join("lib"))
          bundle = relative_to_css(File.expand_path(ENGINE_BUNDLE, destination_root))
          theme = relative_to_css(theme_path)
          lines = [ BLOCK_START, %(@source "#{source}";), %(@import "#{bundle}";), %(@import "#{theme.start_with?('.') ? theme : "./#{theme}"}";), BLOCK_END ]
          lines.join(eol || "\n")
        end

        def with_block(css)
          eol = css.include?("\r\n") ? "\r\n" : "\n"
          if css.include?(BLOCK_START) || css.include?(BLOCK_END)
            unless css.scan(MANAGED_BLOCK).size == 1 && css.scan(BLOCK_START).size == 1 && css.scan(BLOCK_END).size == 1
              raise Thor::Error, "#{options[:css]} has missing, repeated or misordered phlex-shadcn markers: fix or remove them"
            end

            return css.sub(MANAGED_BLOCK) { managed_block(eol) }
          end
          unless css.match?(TAILWIND_IMPORT)
            raise Thor::Error, %(#{options[:css]} does not contain @import "tailwindcss"; add these lines after it by hand:#{eol}#{managed_block(eol)})
          end

          css.sub(TAILWIND_IMPORT) { |import| "#{import}#{eol}#{managed_block(eol)}" }
        end
      end
    end
  end
end
