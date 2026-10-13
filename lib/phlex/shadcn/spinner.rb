# frozen_string_literal: true

# shadcn `Spinner` (new-york-v4). Spec: docs/shadcn-port/specs/spinner.md. Static: no controller, no data-slot.
class Phlex::Shadcn::Spinner < Phlex::Shadcn::Base
  def initialize(**attrs)
    @attrs = attrs
  end

  def view_template(&)
    attrs = @attrs.dup
    # lucide Icon consumes `color` as the stroke attribute instead of forwarding it.
    attrs[:stroke] = attrs.delete(:color) if attrs.key?(:color)
    # lucide omits aria-hidden when role/aria props are present; Spinner always passes both.
    defaults = { role: "status", aria: { label: "Loading", hidden: nil }, class: "size-4 animate-spin" }
    render(Phlex::Shadcn::Icon.new("loader-circle", **merge_attrs(defaults, attrs)), &)
  end
end
