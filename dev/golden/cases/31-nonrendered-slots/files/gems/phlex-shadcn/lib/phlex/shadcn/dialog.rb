# frozen_string_literal: true

# Seeded: renders every slot Radix actually puts in the DOM, and deliberately NOT the `dialog` / `dialog-portal` slots
# (Radix Dialog.Root and Dialog.Portal render no element). G1 must not report those as missing. Tokens/parts are
# incomplete on purpose: other findings are fine, G1_SLOT_MISSING is not.
module Components
  module V2
    class Dialog < Phlex::Shadcn::Base
      class Trigger < Phlex::Shadcn::Base; def view_template = button(data: { slot: "dialog-trigger" }); end
      class Overlay < Phlex::Shadcn::Base; def view_template = div(data: { slot: "dialog-overlay" }); end
      class Content < Phlex::Shadcn::Base; def view_template = div(data: { slot: "dialog-content" }); end
      class Header < Phlex::Shadcn::Base; def view_template = div(data: { slot: "dialog-header" }); end
      class Footer < Phlex::Shadcn::Base; def view_template = div(data: { slot: "dialog-footer" }); end
      class Title < Phlex::Shadcn::Base; def view_template = h2(data: { slot: "dialog-title" }); end
      class Description < Phlex::Shadcn::Base; def view_template = p(data: { slot: "dialog-description" }); end
      class Close < Phlex::Shadcn::Base; def view_template = button(data: { slot: "dialog-close" }); end
    end
  end
end
