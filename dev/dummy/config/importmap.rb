# frozen_string_literal: true

# The gem's own pins (controllers/chadcn/*, chadcn/primitives/*, floating-ui) come from its engine.
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
