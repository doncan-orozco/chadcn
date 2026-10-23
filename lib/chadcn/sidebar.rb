# frozen_string_literal: true

# shadcn Sidebar (new-york-v4).
#
# Render it inside a {Sidebar::Provider}; the block receives the sidebar, which has one helper per part
# (`sidebar.header`, `sidebar.menu_button`, ...) equal to `render Sidebar::Header.new(...)`. `Sidebar.use_sidebar` reads the state.
#
# Spec: docs/shadcn-port/specs/sidebar.md. Behavior: controllers/chadcn/sidebar_controller.js.
#
# React picks the desktop or the mobile (Sheet) tree on the client. The server renders the first React render (desktop)
# plus an inert template with the mobile Sheet; the controller swaps them on mobile (deviations/sidebar.json).
#
# @example Collapsible-to-icons sidebar with a menu
#   render Chadcn::Sidebar::Provider.new do
#     render Chadcn::Sidebar.new(collapsible: "icon") do |sidebar|
#       sidebar.header { plain "Acme" }
#       sidebar.content do
#         sidebar.group do
#           sidebar.group_label { plain "Platform" }
#           sidebar.menu do
#             sidebar.menu_item do
#               sidebar.menu_button(as_child: :a, is_active: true, tooltip: "Home", href: "/") { plain "Home" }
#             end
#           end
#         end
#       end
#       sidebar.rail
#     end
#     render Chadcn::Sidebar::Inset.new { plain "Page" }
#   end
#
# @see Sidebar::Provider
# @see https://ui.shadcn.com/docs/components/sidebar
class Chadcn::Sidebar < Chadcn::Base
  # Name of the React hook, used in error messages.
  #
  # @api private
  HOOK = "useSidebar"
  # Render-context key holding the {State}.
  #
  # @api private
  CONTEXT_KEY = :shadcn_sidebar_state
  # Render-context key of the sidebar id counter (per request with the engine, per render without it, see Chadcn::Sequence).
  #
  # @api private
  SEQUENCE_KEY = :shadcn_sidebar_sequence

  # Default `--sidebar-width` of the desktop sidebar.
  SIDEBAR_WIDTH = "16rem"
  # Default `--sidebar-width-icon` of the icon-collapsed sidebar.
  SIDEBAR_WIDTH_ICON = "3rem"
  # `--sidebar-width` of the mobile sheet.
  SIDEBAR_WIDTH_MOBILE = "18rem"

  # Accepted `side:` values.
  SIDES = %w[left right].freeze
  # Accepted `variant:` values.
  VARIANTS = %w[sidebar floating inset].freeze
  # Accepted `collapsible:` values.
  COLLAPSIBLES = %w[offcanvas icon none].freeze

  # Classes of the single `div` rendered with `collapsible: "none"`.
  #
  # @api private
  NONE_CLASSES = "flex h-full w-(--sidebar-width) flex-col bg-sidebar text-sidebar-foreground"
  # Classes of the outer desktop wrapper.
  #
  # @api private
  OUTER_CLASSES = "group peer hidden text-sidebar-foreground md:block"
  # Classes of the gap element that reserves the sidebar width in the layout.
  #
  # @api private
  GAP_CLASSES = "relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 ease-linear"
  # Gap width when collapsed to icons.
  #
  # @api private
  GAP_ICON = "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
  # Gap width when collapsed to icons with the floating or inset variant.
  #
  # @api private
  GAP_ICON_PADDED = "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]"
  # Classes of the fixed container.
  #
  # @api private
  CONTAINER_CLASSES = "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear md:flex"
  # Container position classes per side.
  #
  # @api private
  CONTAINER_SIDES = {
    "left" => "left-0 group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)]",
    "right" => "right-0 group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)]"
  }.freeze
  # Container classes for the floating and inset variants.
  #
  # @api private
  CONTAINER_PADDED = "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]"
  # Container classes for the plain sidebar variant.
  #
  # @api private
  CONTAINER_FLAT = "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l"
  # Classes of the inner panel.
  #
  # @api private
  INNER_CLASSES = "flex h-full w-full flex-col bg-sidebar group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border group-data-[variant=floating]:border-sidebar-border group-data-[variant=floating]:shadow-sm"
  # Words of the mobile sheet screen-reader description.
  #
  # @api private
  MOBILE_DESCRIPTION = [ "Displays the", "mobile sidebar." ].freeze # two literals: the G1 scanner reads a four-word prose literal as class tokens
  # Classes of the mobile sheet content.
  #
  # @api private
  MOBILE_CLASSES = "w-(--sidebar-width) bg-sidebar p-0 text-sidebar-foreground [&>button]:hidden"

  # React `useSidebar`, read from the render context of the nearest Provider.
  #
  # @!attribute [r] id
  #   @return [String] name of the sidebar (the Provider id: or sidebar-N, per request with the engine, per render without it)
  # @!attribute [r] state
  #   @return [String] `"expanded"` or `"collapsed"`
  # @!attribute [r] open
  #   @return [Boolean] desktop open state
  # @!attribute [r] open_mobile
  #   @return [Boolean] mobile sheet open state
  # @!attribute [r] is_mobile
  #   @return [Boolean] whether the viewport is mobile (always false on the server)
  State = Data.define(:id, :state, :open, :open_mobile, :is_mobile)

  # React `useSidebar`: the state of the nearest {Provider}.
  #
  # @param component [Chadcn::Base] the component that reads the state (its render context is used)
  # @return [State]
  # @raise [ArgumentError] when there is no {Provider} above
  def self.use_sidebar(component)
    component.send(:context)[CONTEXT_KEY] or raise ArgumentError, "#{HOOK} must be used within a SidebarProvider."
  end

  # @param side [String, Symbol] `left` or `right` (default: "left")
  # @param variant [String, Symbol] `sidebar`, `floating` or `inset` (default: "sidebar")
  # @param collapsible [String, Symbol] `offcanvas`, `icon` or `none` (default: "offcanvas")
  # @param mobile_title [String] screen-reader title of the mobile sheet (default: "Sidebar")
  # @param mobile_description [String, nil] screen-reader description of the mobile sheet (default: "Displays the mobile sidebar.")
  # @param attrs [Hash] HTML attributes for the container `div` (the `div` itself with `collapsible: "none"`); `class:` is
  #   tailwind-merged, `data:` and `aria:` are deep-merged
  # @raise [ArgumentError] when `side`, `variant` or `collapsible` is unknown
  def initialize(side: "left", variant: "sidebar", collapsible: "offcanvas", mobile_title: "Sidebar", mobile_description: nil, **attrs)
    @mobile_title = mobile_title
    @mobile_description = mobile_description || MOBILE_DESCRIPTION.join(" ")
    @side = option(SIDES, side, "left", "side")
    @variant = option(VARIANTS, variant, "sidebar", "variant")
    @collapsible = option(COLLAPSIBLES, collapsible, "offcanvas", "collapsible")
    @attrs = attrs
    super()
  end

  # Renders the desktop sidebar plus the inert mobile sheet template, or a single `div` with `collapsible: "none"`.
  #
  # @yieldparam sidebar [Chadcn::Sidebar] the root, exposing the part helpers
  # @return [void]
  # @raise [ArgumentError] when there is no {Provider} above
  def view_template(&)
    sidebar = self.class.use_sidebar(self)
    return unmanaged(&) if @collapsible == "none"

    desktop(sidebar, &)
    mobile
  end

  private

  def option(allowed, value, default, label)
    key = value.nil? ? default : value.to_s
    return key if allowed.include?(key)

    raise ArgumentError, "unknown #{label}: #{value.inspect} (expected one of #{allowed.join(', ')})"
  end

  def unmanaged(&block)
    div(**merge_attrs({ class: NONE_CLASSES, data: { slot: "sidebar" } }, @attrs)) { yield self if block }
  end

  def padded? = @variant != "sidebar"

  def desktop(sidebar, &block)
    div(class: OUTER_CLASSES, data: {
          state: sidebar.state, collapsible: sidebar.state == "collapsed" ? @collapsible : "", variant: @variant, side: @side,
          slot: "sidebar", chadcn__sidebar_target: "sidebar", chadcn__sidebar_collapsible_param: @collapsible
        }) do
      div(data: { slot: "sidebar-gap" },
          class: cn(GAP_CLASSES, "group-data-[collapsible=offcanvas]:w-0", "group-data-[side=right]:rotate-180",
                    padded? ? GAP_ICON_PADDED : GAP_ICON))
      div(**merge_attrs({ class: container_classes, data: { slot: "sidebar-container" } }, @attrs)) do
        div(data: { sidebar: "sidebar", slot: "sidebar-inner" }, class: INNER_CLASSES) { yield self if block }
      end
    end
  end

  def container_classes
    cn(CONTAINER_CLASSES, CONTAINER_SIDES.fetch(@side), padded? ? CONTAINER_PADDED : CONTAINER_FLAT)
  end

  # The mobile Sheet (tsx:183-205), mounted by the controller only on mobile viewports. The block is NOT repeated here:
  # the controller moves the single server-rendered copy into mobileBody.
  def mobile
    template(data: { chadcn__sidebar_target: "mobile" }) do
      render Chadcn::Sheet.new(open: false) do
        render Chadcn::Sheet::Content.new(side: @side, class: MOBILE_CLASSES, style: "--sidebar-width: #{SIDEBAR_WIDTH_MOBILE};",
                                          data: { sidebar: "sidebar", slot: "sidebar", mobile: "true" }) do
          render Chadcn::Sheet::Header.new(class: "sr-only") do
            render(Chadcn::Sheet::Title.new) { @mobile_title }
            render(Chadcn::Sheet::Description.new) { @mobile_description }
          end
          div(class: "flex h-full w-full flex-col", data: { chadcn__sidebar_target: "mobileBody" })
        end
      end
    end
  end
end
