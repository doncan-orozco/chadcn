# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # Judges the ejected components (dev/decisions/eject-override.md): an ejected file is a snapshot of the gem's file, so after a gem
        # update it can be stale. It warns, per component, when
        #
        # - the gem's file changed since the copy (the header's SHA-256 is not the gem file's any more: the copy misses the change);
        # - the gem has parts the ejected unit lacks (a compound component is ejected as a unit, so a part added upstream is not loaded);
        # - an ejected file has no header (it was not made by the generator, so nothing says what it was copied from);
        # - the gem no longer has the file the header says the copy came from.
        #
        # A file in the override directory that carries no header and shadows no gem file is the app's own component and is left alone.
        #
        # @api private
        module Ejected
          NAME = "ejected components"
          FIX = "bin/rails g phlex:shadcn:eject %<unit>s --diff shows the change; --force copies the new file over yours (merge your edits first)"
          private_constant :FIX

          # @param context [Context]
          # @param override_dir [String, nil] the override directory; the configured one by default
          # @param gem_dir [String] the gem's component sources
          # @return [Result]
          def self.call(context, override_dir: Shadcn.config.override_dir, gem_dir: Overrides::GEM_DIR)
            installed = context.gem_version("phlex-shadcn")&.to_s || VERSION
            units = Overrides.ejected_units(override_dir, gem_dir: gem_dir)
            by_unit = units.to_h { |unit| [ unit, problems(unit, override_dir, gem_dir, installed) ] }.reject { |_, found| found.empty? }
            problems = by_unit.values.flatten + orphans(override_dir, gem_dir)
            return Result.passed(NAME, summary(units, override_dir)) if problems.empty?

            Result.warning(NAME, problems.join("; "), fix: format(FIX, unit: by_unit.keys.join(" ").then { |names| names.empty? ? "<component>" : names }))
          end

          # @return [String]
          def self.summary(units, override_dir)
            return "nothing ejected (every component loads from the gem)" if units.empty?

            "#{units.size} ejected (#{units.join(', ')}), none stale (#{override_dir})"
          end
          private_class_method :summary

          # @return [Array<String>] one message per problem of the unit
          def self.problems(unit, override_dir, gem_dir, installed)
            found = Overrides.unit_files(unit, dir: override_dir).flat_map do |rel|
              header = Overrides.parse_header(File.read(File.join(override_dir, rel), encoding: "UTF-8"))
              next stale(unit, rel, header, gem_dir, installed) if header
              next [] unless File.file?(File.join(gem_dir, rel)) # the app's own file next to an ejected unit

              [ "#{unit} (#{rel}) has no ejected header, so nothing says which gem file it was copied from" ]
            end
            missing = Overrides.unit_files(unit, dir: gem_dir) - Overrides.unit_files(unit, dir: override_dir)
            found << "the gem has parts #{unit} lacks (#{missing.join(', ')}); eject them too or the component cannot load them" if missing.any? && unit_root?(unit, override_dir)
            found
          end
          private_class_method :problems

          # A component ejected through its root file takes the whole gem directory with it; a part ejected alone does not.
          def self.unit_root?(unit, override_dir) = File.file?(File.join(override_dir, "#{unit}.rb"))
          private_class_method :unit_root?

          # @return [Array<String>]
          def self.stale(unit, rel, header, gem_dir, installed)
            gem_file = File.join(gem_dir, header[:source].delete_prefix("lib/phlex/shadcn/"))
            return [ "#{unit} (#{rel}) was copied from phlex-shadcn #{header[:version]}, but the gem has no such file any more" ] unless File.file?(gem_file)
            return [] if Overrides.digest(File.read(gem_file, encoding: "UTF-8")) == header[:digest]

            [ "#{unit} (#{rel}) changed upstream: copied from phlex-shadcn #{header[:version]}, installed #{installed}" ]
          end
          private_class_method :stale

          # Files with an ejected header whose gem file is gone: they are never loaded as a replacement for anything.
          # @return [Array<String>]
          def self.orphans(override_dir, gem_dir)
            return [] unless override_dir && File.directory?(override_dir)

            units = Overrides.ejected_units(override_dir, gem_dir: gem_dir)
            covered = units.flat_map { |unit| Overrides.unit_files(unit, dir: override_dir) }
            (Dir.glob("**/*.rb", base: override_dir) - covered).filter_map do |rel|
              next unless Overrides.parse_header(File.read(File.join(override_dir, rel), encoding: "UTF-8"))

              "#{rel} was ejected from phlex-shadcn but the gem no longer has that file"
            end
          end
          private_class_method :orphans
        end
      end
    end
  end
end
