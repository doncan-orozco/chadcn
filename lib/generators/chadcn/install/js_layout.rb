# frozen_string_literal: true

module Chadcn
  module Generators
    # Where the gem's JavaScript lives and where an esbuild app gets its copies, see dev/decisions/js-bundlers.md. Plain Ruby, no Rails:
    # it lives here, next to the install generator, because gem_check (GEM_ESCAPES_ROOT) allows app/... layout paths only in the
    # generators; {Chadcn::JsBundle} (lib/chadcn/js_bundle.rb, loaded by Zeitwerk) reads them from here, the same
    # precedent as SprocketsManifest.
    #
    # @api private
    module JsLayout
      # The JavaScript root, relative to the app root and to the gem's root alike.
      ROOT = "app/javascript"
      # The Stimulus controllers, relative to the app root (the copies) and to the gem's root (the sources) alike.
      CONTROLLERS_DIR = "app/javascript/controllers/chadcn"
      # The primitives the controllers import, in the gem and in the app copies.
      PRIMITIVES_DIR = "app/javascript/chadcn/primitives"
      # The bundler's entry file, which imports the registration file.
      ENTRY = "app/javascript/application.js"
    end
  end
end
