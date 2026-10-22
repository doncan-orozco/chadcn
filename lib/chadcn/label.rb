# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn/ui Label over Radix Label. Spec: docs/shadcn-port/specs/label.md
#
# A form label, the shadcn `Label` over Radix Label (its `chadcn--label` controller blocks text selection on double click).
#
# @example
#   render Chadcn::Label.new(html_for: "email") { "Email" }
class Chadcn::Label < Chadcn::Base
  # Label classes, including the disabled styles driven by a sibling or a group.
  # @return [String]
  #
  # @api private
  BASE = "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50"
  # Stimulus identifier.
  #
  # @api private
  CONTROLLER = "chadcn--label"
  # Stimulus action descriptor.
  #
  # @api private
  ACTION = "mousedown->chadcn--label#mousedown"

  # @param html_for [String, nil] id of the labelled control, rendered as `for`; wins over an explicit `for:`
  # @param as_child [false, Symbol, String, Chadcn::Base]
  #   a tag or component instance to render instead of the `<label>`; false renders the default element
  # @param attrs [Hash] HTML attributes (`class:`, `data:`, `aria:`...)
  def initialize(html_for: nil, as_child: false, **attrs)
    @as_child = as_child
    @attrs = html_for.nil? ? attrs : attrs.except(:for, "for").merge(html_for:)
    super()
  end

  # @yield the label content (optional; a label without a block renders empty)
  # @return [void]
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
    controllers = [ data[:controller], CONTROLLER ].reject_blank.flat_map { |c| c.to_s.split }.uniq.join(" ")
    merged.merge(data: data.merge(controller: controllers, action: [ data[:action], ACTION ].reject_blank.join(" ")))
  end
end
