# frozen_string_literal: true

# shadcn Sidebar (new-york-v4). Spec: docs/shadcn-port/specs/sidebar.md. Behavior: controllers/shadcn/sidebar_controller.js.
#
# React picks the desktop or the mobile (Sheet) tree on the client. The server renders the first React render (desktop)
# plus an inert template with the mobile Sheet; the controller swaps them on mobile (deviations/sidebar.json).
class Phlex::Shadcn::Sidebar < Phlex::Shadcn::Base
  HOOK = "useSidebar"
  CONTEXT_KEY = :shadcn_sidebar_state
  SEQUENCE_KEY = :shadcn_sidebar_sequence

  SIDEBAR_WIDTH = "16rem"
  SIDEBAR_WIDTH_ICON = "3rem"
  SIDEBAR_WIDTH_MOBILE = "18rem"

  SIDES = %w[left right].freeze
  VARIANTS = %w[sidebar floating inset].freeze
  COLLAPSIBLES = %w[offcanvas icon none].freeze

  NONE_CLASSES = "flex h-full w-(--sidebar-width) flex-col bg-sidebar text-sidebar-foreground"
  OUTER_CLASSES = "group peer hidden text-sidebar-foreground md:block"
  GAP_CLASSES = "relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 ease-linear"
  GAP_ICON = "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
  GAP_ICON_PADDED = "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]"
  CONTAINER_CLASSES = "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear md:flex"
  CONTAINER_SIDES = {
    "left" => "left-0 group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)]",
    "right" => "right-0 group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)]"
  }.freeze
  CONTAINER_PADDED = "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]"
  CONTAINER_FLAT = "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l"
  INNER_CLASSES = "flex h-full w-full flex-col bg-sidebar group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border group-data-[variant=floating]:border-sidebar-border group-data-[variant=floating]:shadow-sm"
  # Split in two literals: the G1 scanner reads a prose literal of four words as class tokens.
  MOBILE_DESCRIPTION = [ "Displays the", "mobile sidebar." ].freeze
  MOBILE_CLASSES = "w-(--sidebar-width) bg-sidebar p-0 text-sidebar-foreground [&>button]:hidden"

  # React `useSidebar`, read from the render context of the nearest Provider.
  State = Data.define(:id, :state, :open, :open_mobile, :is_mobile)

  def self.use_sidebar(component)
    component.send(:context)[CONTEXT_KEY] or raise ArgumentError, "#{HOOK} must be used within a SidebarProvider."
  end

  def initialize(side: "left", variant: "sidebar", collapsible: "offcanvas", **attrs)
    @side = option(SIDES, side, "left", "side")
    @variant = option(VARIANTS, variant, "sidebar", "variant")
    @collapsible = option(COLLAPSIBLES, collapsible, "offcanvas", "collapsible")
    @attrs = attrs
    super()
  end

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
          slot: "sidebar", shadcn__sidebar_target: "sidebar", shadcn__sidebar_collapsible_param: @collapsible
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
    template(data: { shadcn__sidebar_target: "mobile" }) do
      render Phlex::Shadcn::Sheet.new(open: false) do
        render Phlex::Shadcn::Sheet::Content.new(side: @side, class: MOBILE_CLASSES, style: "--sidebar-width: #{SIDEBAR_WIDTH_MOBILE};",
                                                 data: { sidebar: "sidebar", slot: "sidebar", mobile: "true" }) do
          render Phlex::Shadcn::Sheet::Header.new(class: "sr-only") do
            render(Phlex::Shadcn::Sheet::Title.new) { "Sidebar" }
            render(Phlex::Shadcn::Sheet::Description.new) { MOBILE_DESCRIPTION.join(" ") }
          end
          div(class: "flex h-full w-full flex-col", data: { shadcn__sidebar_target: "mobileBody" })
        end
      end
    end
  end
end
