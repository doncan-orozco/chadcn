# frozen_string_literal: true

# shadcn TabsList: Radix List over the roving focus group.
#
# @example
#   tabs.list(variant: "line") { tabs.trigger(value: "a") { "A" } }
class Chadcn::Tabs::List < Chadcn::Base
  include Chadcn::Tabs::Support

  # @param variant [String, Symbol] `"default"` or `"line"`
  # @param loop [Boolean] whether keyboard navigation wraps around
  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the list (`style:` is joined after the outline reset)
  def initialize(variant: "default", loop: true, as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    @loop = loop
    @as_child = as_child
    @style = attrs.delete(:style)
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template(&)
    root = root_context
    attrs = merge_attrs({
                          role: "tablist",
                          tabindex: 0,
                          style: join_style("outline: none", @style),
                          class: Chadcn::Tabs.list_variants(variant: @variant),
                          aria: { orientation: root[:orientation] },
                          data: { orientation: root[:orientation], slot: "tabs-list", variant: @variant,
                                  chadcn__tabs_target: "list", chadcn__tabs_loop_value: @loop.to_s }
                        }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end
