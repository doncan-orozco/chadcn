# frozen_string_literal: true

module Phlex
  module Shadcn
    module Generators
      # Where a Sprockets app declares the assets it serves, see dev/decisions/sprockets.md. Plain Ruby, no Rails: it lives here, next to
      # js_bundle.rb, because gem_check (GEM_ESCAPES_ROOT) allows app/... layout paths only in the generators, and the doctor reads them
      # from here (same precedent as JsBundle).
      #
      # @api private
      module SprocketsManifest
        # The manifest, relative to the app root.
        PATH = "app/assets/config/manifest.js"
        # The directory the Tailwind build is written to, relative to the app root.
        BUILDS_DIR = "app/assets/builds"
        # A link of the builds directory (`//= link_tree ../builds`) or of the compiled file (`//= link tailwind.css`).
        BUILDS_LINK = %r{^//=\s*(?:link_(?:tree|directory)\s+\.\./builds(?:\s+\.css)?|link\s+tailwind\.css)\s*$}

        # @param text [String] the manifest's text
        # @return [Boolean] whether it declares the Tailwind build
        def self.links_builds?(text) = text.match?(BUILDS_LINK)
      end
    end
  end
end
