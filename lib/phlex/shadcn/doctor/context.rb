# frozen_string_literal: true

require "pathname"
require "shellwords"

module Phlex
  module Shadcn
    module Doctor
      # What the checks look at: the app's files and the gem versions in its bundle. Everything is injectable, so the checks are tested
      # against fixture directories and need no framework.
      #
      # @api private
      class Context
        # The Tailwind entry file `rails g phlex:shadcn:install` edits, relative to the app root.
        DEFAULT_CSS = File.join("app", "assets", "tailwind", "application.css")
        # The supported Phlex range when the gem's own specification is not loaded.
        DEFAULT_PHLEX_REQUIREMENT = "~> 2.3"

        # The installer, which writes the managed block and the theme files: the one-line fix of most failures.
        INSTALL = "bin/rails g phlex:shadcn:install"
        # The fix when the app has no theme directory configured.
        THEME_DIR_FIX = "set config.phlex_shadcn.theme_dir in config/application.rb"
        # An `@import "..."` line of the entry file.
        IMPORT = /^@import\s+["']([^"']+)["']/
        # An `@source "..."` line of the entry file.
        SOURCE = /^@source\s+["']([^"']+)["']/

        # The block `rails g phlex:shadcn:install` writes, from its start marker to its end marker.
        MANAGED_BLOCK = %r{/\* phlex-shadcn:start \(managed by rails g phlex:shadcn:install\) \*/.*?/\* phlex-shadcn:end \*/}m

        # @return [Pathname] the app root
        attr_reader :root
        # @return [Pathname, nil] the theme directory (theme.css and presets/), nil when none is configured
        attr_reader :theme_dir
        # @return [Pathname] the gem's root, where the `@source` line has to point
        attr_reader :gem_root
        # @return [Hash{String => Gem::Version}] the gems of the bundle
        attr_reader :gems

        # @param root [String, Pathname] the app root
        # @param theme_dir [String, Pathname, nil] absolute, or relative to the root; nil when the app has none configured
        # @param css [String] the Tailwind entry file, relative to the root
        # @param gems [Hash{String => Gem::Version}, nil] the bundle's gems; the loaded specifications by default
        # @param gem_root [Pathname] the root of the gem
        # @param hide_tailwind_stubs [Boolean] `config.phlex_shadcn.hide_tailwind_stubs`
        # @param phlex_requirement [String, Gem::Requirement, nil] the supported Phlex range; the gem's dependency by default
        # @param propshaft_hook [Boolean, nil] whether Propshaft has the private hook the stub filter wraps; probed from the loaded
        #   Propshaft (or, without it, its version) by default
        def initialize(root:, theme_dir: nil, css: DEFAULT_CSS, gems: nil, gem_root: Shadcn.root, hide_tailwind_stubs: true,
                       phlex_requirement: nil, propshaft_hook: nil)
          @root = Pathname.new(root)
          @theme_dir = theme_dir && File.expand_path(theme_dir.to_s, @root).then { |dir| Pathname.new(dir) }
          @css = css
          @gems = gems || Gem.loaded_specs.transform_values(&:version)
          @gem_root = Pathname.new(gem_root)
          @hide_tailwind_stubs = hide_tailwind_stubs
          @phlex_requirement = phlex_requirement
          @propshaft_hook = propshaft_hook
        end

        # @return [Boolean] whether Propshaft has the private one-argument hook the stub filter wraps (the filter's own probe, read-only:
        #   the supported Propshaft is 1.2 and 1.3); false when the filter cannot install, so the stubs stay linked
        def propshaft_hook?
          return @propshaft_hook unless @propshaft_hook.nil?

          if defined?(::Propshaft::LoadPath)
            ::Propshaft::LoadPath.private_method_defined?(:without_dotfiles) && ::Propshaft::LoadPath.instance_method(:without_dotfiles).arity == 1
          else
            Gem::Requirement.new(">= 1.2", "< 1.4").satisfied_by?(gem_version("propshaft") || Gem::Version.new("0"))
          end
        end

        # @return [String] the installer command for this app's Tailwind entry file (`--css` when it is not the default)
        def install_command = @css == DEFAULT_CSS ? INSTALL : "#{INSTALL} --css #{Shellwords.escape(@css)}"

        # @return [Boolean] `config.phlex_shadcn.hide_tailwind_stubs`
        def hide_tailwind_stubs? = @hide_tailwind_stubs

        # @param name [String] gem name
        # @return [Gem::Version, nil] the version in the bundle, nil when the gem is absent
        def gem_version(name) = gems[name]

        # @return [Gem::Requirement] the Phlex versions the gem supports
        def phlex_requirement
          requirement = @phlex_requirement || Gem.loaded_specs["phlex-shadcn"]&.dependencies&.find { |dep| dep.name == "phlex" }&.requirement
          Gem::Requirement.new(requirement || DEFAULT_PHLEX_REQUIREMENT)
        end

        # @return [Pathname] the Tailwind entry file
        def css_path = root.join(@css)

        # @return [String] the Tailwind entry file as the app writes it in messages
        def css_name = @css

        # @return [String, nil] the Tailwind entry file's text, nil when it is missing
        def css_text
          return @css_text if defined?(@css_text)

          @css_text = read(css_path)
        end

        # @param file [Pathname]
        # @return [String, nil] the file's text, nil when it is missing
        # @raise [Encoding::InvalidByteSequenceError] when the file is not valid UTF-8 (the doctor reports it as unreadable, not as a bug)
        def read(file)
          return nil unless file.file?

          text = file.read(encoding: "UTF-8")
          raise Encoding::InvalidByteSequenceError, "#{file} is not valid UTF-8" unless text.valid_encoding?

          text
        end

        # @return [String, nil] the managed `phlex-shadcn:start` ... `phlex-shadcn:end` block of the entry file, nil when it is absent
        def managed_block = css_text&.[](MANAGED_BLOCK)

        # @return [Array<Pathname>] the files the managed block imports, relative to the entry file, without the `.css` suffix (empty
        #   without a block)
        def block_imports = managed_block.to_s.scan(IMPORT).flatten.map { |value| resolve_from_css(value) }

        # @return [Array<Pathname>] the directories the managed block's `@source` lines name (empty without a block)
        def block_sources = managed_block.to_s.scan(SOURCE).flatten.map { |value| resolve_from_css(value) }

        # @param value [String] a path as written in the entry file's `@source` or `@import`
        # @return [Pathname] the file or directory it names, relative to the entry file, without a `.css` suffix
        def resolve_from_css(value) = Pathname.new(File.expand_path(value.delete_suffix(".css"), css_path.dirname))

        # @param relative [String] a path relative to the app root
        # @return [Pathname]
        def path(relative) = root.join(relative)
      end
    end
  end
end
