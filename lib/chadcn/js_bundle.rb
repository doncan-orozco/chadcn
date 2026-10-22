# frozen_string_literal: true

require "json"
require "pathname"
require_relative "../generators/chadcn/install/js_layout"

module Chadcn
  # The gem's JavaScript as files an esbuild (jsbundling-rails) app can bundle, see dev/decisions/js-bundlers.md. Plain Ruby, no
  # framework: the install generator writes what {.files} returns and the doctor compares the app with it.
  #
  # The gem's controllers and primitives import each other by the importmap names (`chadcn/primitives/presence`,
  # `controllers/chadcn/dialog_controller`), which a bundler cannot resolve. The copies get relative specifiers instead; nothing
  # else in a file changes except the header line.
  #
  # @api private
  module JsBundle
    # Where the copies live, relative to the app root.
    CONTROLLERS_DIR = Generators::JsLayout::CONTROLLERS_DIR
    PRIMITIVES_DIR = Generators::JsLayout::PRIMITIVES_DIR
    INDEX = "#{CONTROLLERS_DIR}/index.js".freeze
    # The npm package floating-ui ships as; the gem vendors 1.8.0 for importmap apps.
    FLOATING_UI = "@floating-ui/dom"
    FLOATING_UI_REQUIREMENT = "^1.8.0"
    # The bundler's entry file, which imports the registration file.
    ENTRY = Generators::JsLayout::ENTRY
    APPLICATION_IMPORT = %(import "./controllers/chadcn")
    # An active (not commented out) import of the registration file, in either quote style.
    APPLICATION_IMPORT_PATTERN = %r{^\s*import\s+["']\./controllers/chadcn(?:/index(?:\.js)?)?["']}
    HEADER = "// Managed by `rails g chadcn:install` (copied from the chadcn gem); edits are overwritten by the next run."
    SPECIFIER = %r{((?:from|import)\s*\(?\s*)(["'])(chadcn/primitives/|controllers/chadcn/)([^"']+)\2}
    CONTROLLER_FILE = /_controller\.js\z/

    # @param root [Pathname, String] the app root
    # @param gems [#key?] the bundle's gem names (a Hash of name => version, or anything answering `key?`)
    # @return [Symbol] :importmap, :esbuild, or :unknown
    def self.pipeline(root, gems)
      root = Pathname.new(root)
      return :importmap if root.join("config/importmap.rb").file?
      return :esbuild if root.join("package.json").file? && (gems.key?("jsbundling-rails") || build_script(root).include?("esbuild"))

      :unknown
    end

    # @param root [Pathname]
    # @return [String] the `scripts.build` of package.json, "" when absent or unreadable
    def self.build_script(root)
      data = JSON.parse(root.join("package.json").read)
      scripts = data.is_a?(Hash) ? data["scripts"] : nil
      scripts.is_a?(Hash) ? scripts["build"].to_s : ""
    rescue JSON::ParserError, SystemCallError
      ""
    end

    # @param gem_root [Pathname] the gem's root
    # @return [Hash{String => String}] app-relative path => content, for the controllers, the primitives and the registration file
    def self.files(gem_root)
      gem_root = Pathname.new(gem_root)
      files = copies(gem_root, CONTROLLERS_DIR, CONTROLLERS_DIR)
              .merge(copies(gem_root, PRIMITIVES_DIR, PRIMITIVES_DIR))
      files[INDEX] = index(files.keys.select { |path| path.start_with?("#{CONTROLLERS_DIR}/") && path.match?(CONTROLLER_FILE) })
      files.sort.to_h
    end

    # @param package_json [String, nil] the app's package.json text
    # @return [Boolean] whether floating-ui is a dependency
    def self.floating_ui?(package_json)
      return false if package_json.nil?

      data = JSON.parse(package_json)
      return false unless data.is_a?(Hash)

      %w[dependencies devDependencies].any? { |key| data[key].is_a?(Hash) && data[key].key?(FLOATING_UI) }
    rescue JSON::ParserError
      false
    end

    # @param paths [Array<String>] app-relative controller paths
    # @return [String] the file registering them as `chadcn--<name>`
    def self.index(paths)
      names = paths.map { |path| File.basename(path, "_controller.js") }.sort
      imports = names.map { |name| %(import #{class_name(name)} from "./#{name}_controller") }
      registrations = names.map { |name| %(application.register("chadcn--#{name.tr('_', '-')}", #{class_name(name)})) }
      [ HEADER, %(import { application } from "../application"), "", *imports, "", *registrations, "" ].join("\n")
    end
    private_class_method :index

    def self.class_name(name) = "#{name.split('_').map(&:capitalize).join}Controller"
    private_class_method :class_name

    def self.copies(gem_root, from, to)
      names = Dir.glob("*.js", base: gem_root.join(from).to_s)
      raise ArgumentError, "no JavaScript files in #{gem_root.join(from)}" if names.empty?

      names.to_h do |name|
        path = gem_root.join(from, name)
        [ "#{to}/#{name}", "#{HEADER}\n#{relative_specifiers(File.read(path), to)}" ]
      end
    end
    private_class_method :copies

    # Rewrites `from "chadcn/primitives/x"` / `from "controllers/chadcn/x"` to the path from the file's directory.
    def self.relative_specifiers(source, directory)
      source.gsub(SPECIFIER) do
        keyword, quote, namespace, name = Regexp.last_match.captures
        relative = Pathname.new("#{Generators::JsLayout::ROOT}/#{namespace}#{name}").relative_path_from(Pathname.new(directory)).to_s
        "#{keyword}#{quote}#{relative.start_with?('.') ? relative : "./#{relative}"}#{quote}"
      end
    end
    private_class_method :relative_specifiers
  end
end
