# frozen_string_literal: true

# Pins of the chadcn engine (added to the host's importmap by Chadcn::Engine).
#
# The controllers live in app/javascript/controllers/shadcn, so the host's eagerLoadControllersFrom("controllers") registers them as
# shadcn--<name>; the shared primitives are imported as shadcn/primitives/<name>; floating-ui is vendored (vendor/javascript).
pin_all_from File.expand_path("../app/javascript/controllers/shadcn", __dir__), under: "controllers/shadcn"
pin_all_from File.expand_path("../app/javascript/shadcn", __dir__), under: "shadcn"

pin "@floating-ui/core", to: "@floating-ui--core.js" # @1.8.0
pin "@floating-ui/dom", to: "@floating-ui--dom.js" # @1.8.0
pin "@floating-ui/utils", to: "@floating-ui--utils.js" # @0.2.12
pin "@floating-ui/utils/dom", to: "@floating-ui--utils--dom.js" # @0.2.12
