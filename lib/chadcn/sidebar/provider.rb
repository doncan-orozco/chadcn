# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn SidebarProvider: the wrapper div, the Stimulus host and the state every other part reads (`useSidebar`).
#
# Wrap the whole layout (sidebar and inset) in it; it yields itself.
#
# @example
#   render Chadcn::Sidebar::Provider.new(default_open: true) do
#     render Chadcn::Sidebar.new(collapsible: "icon") { |sidebar| sidebar.content { plain "Menu" } }
#     render Chadcn::Sidebar::Inset.new { plain "Page" }
#   end
# @see Chadcn::Sidebar
class Chadcn::Sidebar::Provider < Chadcn::Base
  # Tailwind classes of the wrapper `div` (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "group/sidebar-wrapper flex min-h-svh w-full has-data-[variant=inset]:bg-sidebar"
  # Name of the cookie where the open state is persisted by the controller.
  #
  # @api private
  COOKIE_NAME = "sidebar_state"
  # Lifetime in seconds of the open-state cookie.
  #
  # @api private
  COOKIE_MAX_AGE = 60 * 60 * 24 * 7

  # `open:` non-nil makes the sidebar controlled: the controller only dispatches open-change and the caller updates the value.
  #
  # @param default_open [Boolean] initial state when uncontrolled (default: true)
  # @param open [Boolean, nil] controlled state (default: nil, uncontrolled)
  # @param style [String, Hash, nil] extra inline style, appended after the `--sidebar-width` variables (default: nil)
  # @param id [String, nil] id of the wrapper element, as in React, and the base of the generated ids (`"docs-sidebar"`).
  #   Without it the element has no id and the base is `sidebar-N`, numbered per request with the engine, per render without it
  # @param attrs [Hash] HTML attributes for the wrapper `div`; `class:` is tailwind-merged, `data:` and `aria:` are deep-merged
  def initialize(default_open: true, open: nil, style: nil, id: nil, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @style = style
    @id = id
    @attrs = attrs
    super()
  end

  # Publishes the sidebar state to the render context and renders the wrapper `div` inside a tooltip provider.
  #
  # @yieldparam provider [Chadcn::Sidebar::Provider] the provider itself; it exposes no part helpers (they live on {Chadcn::Sidebar})
  # @return [void]
  def view_template(&block)
    previous = context[Chadcn::Sidebar::CONTEXT_KEY]
    context[Chadcn::Sidebar::CONTEXT_KEY] = state
    render Chadcn::Tooltip::Provider.new(delay_duration: 0) do
      div(**merge_attrs({ id: @id, class: CLASSES, style: style_attribute, data: wrapper_data }, @attrs.except(:style))) { yield self if block }
    end
  ensure
    context[Chadcn::Sidebar::CONTEXT_KEY] = previous
  end

  private

  def state
    id = @id || "sidebar-#{next_sequence(Chadcn::Sidebar::SEQUENCE_KEY)}"
    Chadcn::Sidebar::State.new(id:, state: @open ? "expanded" : "collapsed", open: @open, open_mobile: false, is_mobile: false)
  end

  def wrapper_data
    {
      slot: "sidebar-wrapper", controller: "chadcn--sidebar", chadcn__sidebar_open_value: @open.to_s, chadcn__sidebar_controlled_value: @controlled.to_s,
      chadcn__sidebar_open_mobile_value: "false", chadcn__sidebar_id_value: context[Chadcn::Sidebar::CONTEXT_KEY].id
    }
  end

  def css_declarations(hash) = hash.map { |name, value| "#{name}: #{value}" }.join("; ")

  # Component variables first, the caller style after (tsx:136-138).
  def style_attribute
    base = { "--sidebar-width" => Chadcn::Sidebar::SIDEBAR_WIDTH, "--sidebar-width-icon" => Chadcn::Sidebar::SIDEBAR_WIDTH_ICON }
    return "#{css_declarations(base.merge(declarations(@style)))};" unless @style.is_a?(String)

    [ "#{css_declarations(base)};", @style.strip ].reject_blank.join(" ")
  end

  def declarations(style)
    (style || {}).to_h { |name, value| [ name.to_s.start_with?("--") ? name.to_s : name.to_s.tr("_", "-"), value ] }
  end
end
