# frozen_string_literal: true

# shadcn/ui Label over Radix Label. Spec: docs/shadcn-port/specs/label.md
class Phlex::Shadcn::Label < Phlex::Shadcn::Base
  BASE = "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50"
  CONTROLLER = "v2--label"
  ACTION = "mousedown->v2--label#mousedown"

  def initialize(html_for: nil, as_child: false, **attrs)
    @as_child = as_child
    @attrs = html_for.nil? ? attrs : attrs.except(:for, "for").merge(html_for:)
    super()
  end

  def view_template(&)
    attrs = merge_attrs({ data: { slot: "label" }, class: BASE }, @attrs)
    return render_as_child(@as_child, **attrs, &) if @as_child

    label(**attrs, &)
  end

  private

  # Caller descriptors first, ours last (Radix calls props.onMouseDown before its own check).
  def merge_attrs(defaults, attrs)
    merged = super
    data = merged[:data]
    controllers = [ data[:controller], CONTROLLER ].compact_blank.flat_map { |c| c.to_s.split }.uniq.join(" ")
    merged.merge(data: data.merge(controller: controllers, action: [ data[:action], ACTION ].compact_blank.join(" ")))
  end
end
