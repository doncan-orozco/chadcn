# frozen_string_literal: true

require "open3"
require "rails/generators"
require "phlex/shadcn"

module Phlex
  module Shadcn
    module Generators
      # `rails g phlex:shadcn:eject <component>...` copies a component of the gem into the app's override directory, where it replaces
      # the gem's file (dev/decisions/eject-override.md):
      #
      #   bin/rails g phlex:shadcn:eject button          # app/components/phlex_shadcn/button.rb
      #   bin/rails g phlex:shadcn:eject dialog          # dialog.rb and every part under dialog/ (a compound component is ejected as a unit)
      #   bin/rails g phlex:shadcn:eject dialog/content  # one part; Dialog and its other parts keep loading from the gem
      #   bin/rails g phlex:shadcn:eject --list          # what can be ejected, what is ejected
      #   bin/rails g phlex:shadcn:eject button --diff   # the gem's current file against your copy
      #
      # Each copied file starts with a header that records the gem version and the SHA-256 of the file it came from, which
      # `bin/rails phlex_shadcn:doctor` uses to warn when the gem's file changed. Nothing is overwritten without `--force`. The loader reads
      # the override directory at boot, so restart the server after ejecting; editing an ejected file reloads like any app file.
      #
      # @api private
      class EjectGenerator < ::Rails::Generators::Base
        desc "Copies phlex-shadcn components into the override directory, where they replace the gem's files."

        argument :components, type: :array, default: [], banner: "button dialog dialog/content"

        class_option :list, type: :boolean, default: false, desc: "List the components that can be ejected and the ones that are"
        class_option :diff, type: :boolean, default: false, desc: "Show the gem's current file against the ejected copy instead of ejecting"
        class_option :dir, type: :string,
                           desc: "The override directory, relative to the app root (default: config.phlex_shadcn.override_dir, " \
                                 "else #{Phlex::Shadcn::Engine::DEFAULT_OVERRIDE_DIR})"

        # Units whose modules the gem's own classes include at load time: they are not reloaded under those classes.
        RELOAD_COUPLED = %w[direction direction/consumer dropdown_menu].freeze
        private_constant :RELOAD_COUPLED

        # Scripted runs (CI) must see a failure: Rails generators exit 0 on Thor::Error unless this is true.
        def self.exit_on_failure? = true

        def eject
          return list if options[:list]

          raise Thor::Error, "name the components to eject, e.g. `eject button` (--list shows them)" if components.empty?

          names = components.map { |name| normalize(name) }
          names.each { |name| validate(name) }
          options[:diff] ? names.each { |name| show_diff(name) } : copy(names)
        end

        private

        def normalize(name) = name.to_s.gsub("::", "/").gsub(/([a-z\d])([A-Z])/, '\1_\2').tr("-", "_").downcase

        def validate(name)
          return if Overrides.ejectable?(name)

          raise Thor::Error, "#{name} is not a phlex-shadcn component (see --list)"
        end

        def override_dir
          @override_dir ||= File.expand_path(options[:dir] || Phlex::Shadcn.config.override_dir || Engine::DEFAULT_OVERRIDE_DIR, destination_root)
        end

        def display(path) = Pathname.new(path).relative_path_from(Pathname.new(destination_root)).to_s

        def list
          ejected = Overrides.ejected_units(override_dir)
          say "Ejectable components (a part is ejected alone as component/part, e.g. dialog/content):"
          Overrides.components.each { |name| say ejected.include?(name) ? "  #{name.ljust(22)}ejected" : "  #{name}" }
          parts = ejected.select { |name| name.include?("/") }
          say "Ejected parts: #{parts.join(', ')}" if parts.any?
          say "Override directory: #{display(override_dir)}#{' (does not exist yet)' unless File.directory?(override_dir)}"
        end

        def copy(names)
          # Root files last: if a write fails half way, only parts are left, and a part shadows only its own gem file.
          files = names.flat_map { |name| Overrides.unit_files(name) }.uniq.sort_by { |rel| [ rel.include?("/") ? 0 : 1, rel ] }
          existing = files.select { |rel| File.exist?(File.join(override_dir, rel)) }
          if options[:skip]
            files -= existing
            existing = []
          end
          if existing.any? && !options[:force]
            raise Thor::Error, "#{existing.map { |rel| display(File.join(override_dir, rel)) }.join(', ')} already exist(s): " \
                               "--force overwrites them (your edits are lost; `--diff` shows them first)"
          end

          files.each { |rel| write(rel) }
          report(names)
        end

        def write(rel)
          text = File.read(File.join(Overrides::GEM_DIR, rel), encoding: "UTF-8")
          header = Overrides.header(version: VERSION, source: "lib/phlex/shadcn/#{rel}", text: text)
          create_file File.join(override_dir, rel), "#{header}\n#{text}", force: true
        end

        def report(names)
          return say("(pretend) would eject #{names.join(', ')} into #{display(override_dir)}") if options[:pretend]

          say "Ejected #{names.join(', ')} into #{display(override_dir)}. Restart the server: the override directory is read at boot."
          coupled = names.select { |name| RELOAD_COUPLED.include?(name) || name.end_with?("/support") }
          say "#{coupled.join(', ')}: gem classes include this code, so an edit of your copy reaches them only after a restart.", :yellow if coupled.any?
          return if File.expand_path(override_dir) == File.expand_path(Phlex::Shadcn.config.override_dir.to_s)

          say "#{display(override_dir)} is not the configured override directory: set config.phlex_shadcn.override_dir to it.", :yellow
        end

        def show_diff(name)
          Overrides.unit_files(name).each do |rel|
            copy_path = File.join(override_dir, rel)
            next say("#{display(copy_path)} is not ejected", :yellow) unless File.file?(copy_path)

            say diff_output(File.join(Overrides::GEM_DIR, rel), copy_path)
          end
        end

        def diff_output(gem_file, copy_path)
          body = Overrides.strip_header(File.read(copy_path, encoding: "UTF-8"))
          output, status = Open3.capture2e("diff", "-u", "--label", "gem: #{gem_file.delete_prefix("#{Overrides::GEM_DIR}/")}", "--label", display(copy_path),
                                           gem_file, "-", stdin_data: body)
          status.success? ? "#{display(copy_path)}: same as the gem's file" : output
        rescue SystemCallError
          "diff is not installed: compare #{gem_file} with #{copy_path} by hand"
        end
      end
    end
  end
end
