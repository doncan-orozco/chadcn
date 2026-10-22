# frozen_string_literal: true

require "digest"

module Chadcn
  # Everything the override directory needs that is plain Ruby (dev/decisions/eject-override.md): which gem files an override
  # directory shadows, which components can be ejected, and the header an ejected copy carries. Used by the gem's loader setup
  # (lib/chadcn.rb), the eject generator and the `ejected` doctor check, so none of them knows how the others read the directory.
  #
  # The loader needs it BEFORE it is set up, so lib/chadcn.rb requires it explicitly and ignores it in the loader (like
  # configuration.rb); the path still follows the constant. It needs no framework.
  #
  # @api private
  module Overrides
    # The gem's component sources: the Zeitwerk root of the gem loader.
    GEM_DIR = File.join(Chadcn::ROOT, "lib/chadcn").freeze
    # Top-level names that are not components: the base class, settings, tooling, the engine and the plain-Ruby helpers.
    INFRASTRUCTURE = %w[base configuration doctor engine icons js_bundle overrides theme values version].freeze
    # First line of an ejected file: the gem version it was copied from, the gem file and the SHA-256 of that file's text.
    HEADER = /\A# Ejected from chadcn (?<version>\S+) \((?<source>[^)\n]+)\) sha256:(?<digest>\h{64})$/
    # The component names `chadcn:eject` accepts: snake_case, with `/` for a nested part (`dialog/content`).
    NAME = %r{\A[a-z][a-z0-9_]*(?:/[a-z][a-z0-9_]*)*\z}

    # Gem files that hold a load-time reference into a unit (an alias constant), so they are ejected and shadowed with it: otherwise the
    # gem loader keeps the first-loaded class behind the alias and an edit of the copy never shows through it.
    COMPANIONS = { "sonner" => %w[toaster.rb], "sonner/toaster" => %w[toaster.rb] }.freeze

    # @param text [String] the text of an ejected file
    # @return [String] the text without its header (the gem file's text as it was copied)
    def self.strip_header(text) = parse_header(text) ? text.sub(/\A(?:#.*\n){2}\n/, "") : text

    # @param text [String] the text of a gem file
    # @return [String] hexadecimal SHA-256
    def self.digest(text) = Digest::SHA256.hexdigest(text)

    # @param version [String] the gem version
    # @param source [String] the gem file, relative to the gem's root
    # @param text [String] the text of the gem file
    # @return [String] the two comment lines that start an ejected copy
    def self.header(version:, source:, text:)
      "# Ejected from chadcn #{version} (#{source}) sha256:#{digest(text)}\n" \
        "# This copy is yours; the gem no longer loads its own file. `bin/rails chadcn:doctor` warns when the gem's file changes.\n"
    end

    # @param text [String] the text of an ejected file
    # @return [Hash{Symbol => String}, nil] `:version`, `:source` and `:digest` of its header, nil when it has none
    def self.parse_header(text)
      match = HEADER.match(text)
      match && match.names.to_h { |name| [ name.to_sym, match[name] ] }
    end

    # The components of the gem, as the names the generator takes: `button`, `alert_dialog`.
    #
    # @param gem_dir [String]
    # @return [Array<String>] sorted
    def self.components(gem_dir: GEM_DIR)
      entries = Dir.children(gem_dir).map { |entry| entry.delete_suffix(".rb") }.uniq
      (entries - INFRASTRUCTURE).select { |entry| File.exist?(File.join(gem_dir, "#{entry}.rb")) || File.directory?(File.join(gem_dir, entry)) }.sort
    end

    # The files that make up one ejectable unit: `dialog` is dialog.rb and everything under dialog/; `dialog/content` is that one part
    # (and what is under dialog/content/, if anything).
    #
    # @param name [String] a component or `component/part`
    # @param dir [String] the directory the names are relative to (the gem or the override directory)
    # @return [Array<String>] relative paths of Ruby files, sorted; empty when the unit does not exist there
    def self.unit_files(name, dir: GEM_DIR)
      files = Dir.glob("#{name}/**/*.rb", base: dir)
      files << "#{name}.rb" if File.file?(File.join(dir, "#{name}.rb"))
      files.concat(COMPANIONS.fetch(name, []).select { |rel| File.file?(File.join(dir, rel)) })
      files.uniq.sort
    end

    # @param name [String] a component or `component/part`
    # @return [Boolean] whether the gem has such a unit
    def self.ejectable?(name, gem_dir: GEM_DIR)
      NAME.match?(name) && !INFRASTRUCTURE.include?(name.split("/").first) && unit_files(name, dir: gem_dir).any?
    end

    # The units the override directory ejects: a component for each top-level file that sits next to its gem file, `component/part`
    # for a part ejected alone.
    #
    # @param override_dir [String]
    # @return [Array<String>] sorted names; files that shadow no gem file are not units
    def self.ejected_units(override_dir, gem_dir: GEM_DIR)
      return [] unless override_dir && File.directory?(override_dir)

      files = Dir.glob("**/*.rb", base: override_dir)
      units = files.filter_map do |rel|
        top = rel.split("/").first
        next top if files.include?("#{top}.rb")

        rel.delete_suffix(".rb")
      end
      units.uniq.select { |unit| unit_files(unit, dir: gem_dir).any? }.sort
    end

    # The gem files the override directory shadows, which the gem's loader must ignore BEFORE it is set up: otherwise the gem
    # registers its constant first and the override is dead code. A component ejected through its root file (`dialog.rb`) shadows the
    # gem's file AND its directory; a part ejected alone shadows only its file.
    #
    # @param override_dir [String, nil]
    # @param gem_dir [String]
    # @return [Array<String>] absolute paths that exist in the gem
    def self.shadowed(override_dir, gem_dir: GEM_DIR)
      return [] unless override_dir && File.directory?(override_dir)

      files = Dir.glob("**/*.rb", base: override_dir).reject { |rel| INFRASTRUCTURE.include?(rel.split("/").first.delete_suffix(".rb")) }
      paths = files.flat_map { |rel| [ File.join(gem_dir, rel), File.join(gem_dir, rel.delete_suffix(".rb")) ] }
      paths.uniq.select { |path| File.exist?(path) }
    end
  end
end
