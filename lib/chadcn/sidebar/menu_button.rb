# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn SidebarMenuButton. With `tooltip:` the button is the trigger of a Tooltip whose content stays hidden unless the
# sidebar is collapsed on desktop (tsx:525-545); the controller keeps `hidden` current.
#
# Rendered inside a {Chadcn::Sidebar::Provider}; also available as `sidebar.menu_button` on the yielded sidebar.
#
# @example
#   sidebar.menu_button(as_child: :a, href: "/", is_active: true, tooltip: "Home") { plain "Home" }
#
# @see Chadcn::Sidebar
class Chadcn::Sidebar::MenuButton < Chadcn::Base
  include Chadcn::Sidebar::Support

  # Spellings of the tooltip class key that are normalized to `:class`.
  #
  # @api private
  TOOLTIP_CLASS_KEYS = %w[className class_name].freeze
  private_constant :TOOLTIP_CLASS_KEYS

  # Classes shared by every variant and size (verbatim from shadcn/ui).
  #
  # @api private
  BASE = "peer/menu-button flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left text-sm ring-sidebar-ring outline-hidden transition-[width,height,padding] group-has-data-[sidebar=menu-action]/menu-item:pr-8 group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:p-2! hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 active:bg-sidebar-accent active:text-sidebar-accent-foreground disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 data-[active=true]:bg-sidebar-accent data-[active=true]:font-medium data-[active=true]:text-sidebar-accent-foreground data-[state=open]:hover:bg-sidebar-accent data-[state=open]:hover:text-sidebar-accent-foreground [&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0"
  # Classes per `variant:`.
  #
  # @api private
  VARIANTS = {
    "default" => "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
    "outline" => "bg-background shadow-[0_0_0_1px_var(--sidebar-border)] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground hover:shadow-[0_0_0_1px_var(--sidebar-accent)]"
  }.freeze
  # Classes per `size:`.
  #
  # @api private
  SIZES = {
    "default" => "h-8 text-sm",
    "sm" => "h-7 text-xs",
    "lg" => "h-12 text-sm group-data-[collapsible=icon]:p-0!"
  }.freeze

  # React `sidebarMenuButtonVariants` (cva: plain concatenation, no merge).
  #
  # @param variant [String, Symbol] one of `default`, `outline` (default: "default")
  # @param size [String, Symbol] one of `default`, `sm`, `lg` (default: "default")
  # @return [String] the class string
  # @raise [KeyError] when `variant` or `size` is unknown
  def self.variants(variant: "default", size: "default")
    [ BASE, VARIANTS.fetch(variant.to_s), SIZES.fetch(size.to_s) ].join(" ")
  end

  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param is_active [Boolean] mark the button as the current page (`data-active`) (default: false)
  # @param variant [String, Symbol] one of `default`, `outline` (default: "default")
  # @param size [String, Symbol] one of `default`, `sm`, `lg` (default: "default")
  # @param tooltip [String, Hash, nil] text of a tooltip shown while the sidebar is collapsed, or the TooltipContent props
  #   plus `children` (default: nil, no tooltip)
  # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
  #   are deep-merged (caller wins)
  # @raise [ArgumentError] when `variant` or `size` is unknown, or on render without a {Chadcn::Sidebar::Provider}
  def initialize(as_child: false, is_active: false, variant: "default", size: "default", tooltip: nil, **attrs)
    @as_child = as_child
    @is_active = is_active
    @variant = resolve(VARIANTS, variant, "variant")
    @size = resolve(SIZES, size, "size")
    @tooltip = tooltip
    @attrs = attrs
    super()
  end

  # Renders the `button` (or the `as_child` child), wrapped in a tooltip when `tooltip:` is given.
  #
  # @yield the content of the element
  # @return [void]
  def view_template(&)
    sidebar = Chadcn::Sidebar.use_sidebar(self)
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
    render Chadcn::Tooltip.new do
      render(Chadcn::Tooltip::Trigger.new(as_child: @as_child || :button, **trigger_attrs(attrs)), &block)
      render(Chadcn::Tooltip::Content.new(**content_options(options, sidebar))) { text }
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
