# frozen_string_literal: true

# shadcn SidebarMenuButton. With `tooltip:` the button is the trigger of a Tooltip whose content stays hidden unless the
# sidebar is collapsed on desktop (tsx:525-545); the controller keeps `hidden` current.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Sidebar::MenuButton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sidebar::Support

  TOOLTIP_CLASS_KEYS = %w[className class_name].freeze
  private_constant :TOOLTIP_CLASS_KEYS

  BASE = "peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left text-sm ring-sidebar-ring outline-hidden transition-[width,height,padding] group-has-data-[sidebar=menu-action]/menu-item:pr-8 group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:p-2! hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 active:bg-sidebar-accent active:text-sidebar-accent-foreground disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 data-[active=true]:bg-sidebar-accent data-[active=true]:font-medium data-[active=true]:text-sidebar-accent-foreground data-[state=open]:hover:bg-sidebar-accent data-[state=open]:hover:text-sidebar-accent-foreground [&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0"
  VARIANTS = {
    "default" => "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
    "outline" => "bg-background shadow-[0_0_0_1px_var(--sidebar-border)] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground hover:shadow-[0_0_0_1px_var(--sidebar-accent)]"
  }.freeze
  SIZES = {
    "default" => "h-8 text-sm",
    "sm" => "h-7 text-xs",
    "lg" => "h-12 text-sm group-data-[collapsible=icon]:p-0!"
  }.freeze

  # React `sidebarMenuButtonVariants` (cva: plain concatenation, no merge).
  def self.variants(variant: "default", size: "default")
    [ BASE, VARIANTS.fetch(variant.to_s), SIZES.fetch(size.to_s) ].join(" ")
  end

  def initialize(as_child: false, is_active: false, variant: "default", size: "default", tooltip: nil, **attrs)
    @as_child = as_child
    @is_active = is_active
    @variant = resolve(VARIANTS, variant, "variant")
    @size = resolve(SIZES, size, "size")
    @tooltip = tooltip
    @attrs = attrs
    super()
  end

  def view_template(&)
    sidebar = Phlex::Shadcn::Sidebar.use_sidebar(self)
    attrs = part_attrs(cn(self.class.variants(variant: @variant, size: @size)),
                       data: { slot: "sidebar-menu-button", sidebar: "menu-button", size: @size, active: @is_active.to_s })
    return render_part(:button, @as_child, attrs, &) if @tooltip.blank_value?

    with_tooltip(attrs, sidebar, &)
  end

  private

  # <Tooltip><TooltipTrigger asChild>{button}</TooltipTrigger><TooltipContent .../></Tooltip>: the trigger merges its
  # props into the button (the button wins), so it is rendered with the button attributes and the same tag or child.
  def with_tooltip(attrs, sidebar, &block)
    options = tooltip_options
    text = options.delete(:children)
    render Phlex::Shadcn::Tooltip.new do
      render(Phlex::Shadcn::Tooltip::Trigger.new(as_child: @as_child || :button, **trigger_attrs(attrs)), &block)
      render(Phlex::Shadcn::Tooltip::Content.new(**content_options(options, sidebar))) { text }
    end
  end

  # The tooltip trigger controller must survive a caller data-controller on the button.
  def trigger_attrs(attrs)
    controllers = attrs.dig(:data, :controller)
    return attrs unless controllers

    attrs.merge(data: attrs[:data].merge(controller: "shadcn--tooltip #{controllers}"))
  end

  def content_options(options, sidebar)
    hidden = sidebar.state != "collapsed" || sidebar.is_mobile
    defaults = { side: "right", align: "center", hidden: }
    # Only the computed `hidden` is kept current by the controller; a caller value is never touched.
    defaults[:data] = { shadcn__sidebar_tooltip: sidebar.id } unless options.key?(:hidden)
    defaults.merge_deep(options)
  end

  # `tooltip:` is a String (the content text) or the TooltipContent props (React or Ruby names) plus `children`.
  def tooltip_options
    return { children: @tooltip } if @tooltip.is_a?(String)

    @tooltip.to_h.to_h do |key, value|
      name = key.to_s
      [ TOOLTIP_CLASS_KEYS.include?(name) ? :class : name.snake_case.to_sym, value ]
    end
  end

  def resolve(table, value, label)
    key = normalize_option(value) || "default"
    return key if table.key?(key)

    raise ArgumentError, "unknown #{label}: #{value.inspect} (expected one of #{table.keys.join(', ')})"
  end
end
