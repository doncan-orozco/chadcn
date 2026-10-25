# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn NavigationMenu over Radix NavigationMenu. Spec: docs/shadcn-port/specs/navigation-menu.md.
# Behavior lives in controllers/chadcn/navigation_menu_controller.js (hosted by the root `nav`).
#
# The block receives the menu, which has one helper per part (`menu.list`, `menu.item`, `menu.trigger`, `menu.content`,
# `menu.link`, `menu.indicator`, `menu.viewport`) equal to `render NavigationMenu::List.new(...)`. The
# viewport is appended automatically unless `viewport: false`.
#
# @example
#   render Chadcn::NavigationMenu.new do |menu|
#     menu.list do
#       menu.item(value: "docs") do
#         menu.trigger { plain "Docs" }
#         menu.content { menu.link(href: "/docs") { plain "Introduction" } }
#       end
#       menu.item { menu.link(href: "/about", class: Chadcn::NavigationMenu.trigger_style) { plain "About" } }
#     end
#   end
#
# @see https://ui.shadcn.com/docs/components/navigation-menu
class Chadcn::NavigationMenu < Chadcn::Base
  include Chadcn::Direction::Consumer

  # Render-context key holding the root state.
  #
  # @api private
  ROOT_KEY = :shadcn_navigation_menu_root
  # Render-context key holding the current item state.
  #
  # @api private
  ITEM_KEY = :shadcn_navigation_menu_item
  # Render-context key of the id counter (per request with the engine, per render without it, see Chadcn::Sequence).
  #
  # @api private
  SEQUENCE_KEY = :shadcn_navigation_menu_sequence
  # Accepted `orientation:` values.
  ORIENTATIONS = %w[horizontal vertical].freeze

  # Classes of the root `nav`.
  #
  # @api private
  CLASSES = "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"
  # React `navigationMenuTriggerStyle()` (cva without variants).
  #
  # @api private
  TRIGGER_STYLE = "group inline-flex h-9 w-max items-center justify-center rounded-md bg-background px-4 py-2 text-sm font-medium transition-[color,box-shadow] outline-none hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 disabled:pointer-events-none disabled:opacity-50 data-[state=open]:bg-accent/50 data-[state=open]:text-accent-foreground data-[state=open]:hover:bg-accent data-[state=open]:focus:bg-accent"

  # `navigationMenuTriggerStyle()` for the caller: the class string that styles a link like a trigger.
  #
  # @example
  #   menu.link(href: "/about", class: Chadcn::NavigationMenu.trigger_style) { plain "About" }
  #
  # @param options [Hash] `class:` is tailwind-merged over the base style
  # @return [String] the class string, for styling a link like a trigger
  def self.trigger_style(**options) = new.send(:cn, TRIGGER_STYLE, options[:class])

  # `value:` non-nil is controlled (the server decides the open item, user actions only dispatch value-change).
  #
  # @param viewport [Boolean] render the shared viewport that hosts the open content (default: true)
  # @param value [String, nil] open item value; non-nil makes the menu controlled (default: nil)
  # @param default_value [String] initially open item value when uncontrolled (default: "")
  # @param delay_duration [Integer] milliseconds before hovering opens an item (default: 200)
  # @param skip_delay_duration [Integer] milliseconds after closing during which hovering opens instantly (default: 300)
  # @param orientation [String, Symbol] `horizontal` or `vertical`; any other value silently falls back to `horizontal` (default: "horizontal")
  # @param dir [String, Symbol, nil] `ltr` or `rtl`; defaults to the nearest {Chadcn::Direction::Provider} (default: nil)
  # @param activation_mode [String, Symbol] `automatic` (hover or focus opens) or `manual`; passed to the Stimulus controller as given,
  #   without validation (default: "automatic")
  # @param id [String, nil] id of the root element, as in React, and the base of the generated ids (`"docs-item-1"`).
  #   Without it the element has no id and the base is `navigation-menu-N`, numbered per request with the engine, per render without it
  # @param attrs [Hash] HTML attributes for the root `nav`; `class:` is tailwind-merged, `data:` and `aria:` are deep-merged
  # @raise [ArgumentError] when id: is empty or contains whitespace, a double quote or a backslash
  def initialize(viewport: true, value: nil, default_value: "", delay_duration: 200, skip_delay_duration: 300,
                 orientation: "horizontal", dir: nil, activation_mode: "automatic", id: nil, **attrs)
    @viewport = viewport
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value).to_s
    @delay_duration = delay_duration
    @skip_delay_duration = skip_delay_duration
    @orientation = ORIENTATIONS.include?(orientation.to_s) ? orientation.to_s : "horizontal"
    @dir = dir
    @activation_mode = activation_mode.to_s
    @id = validated_id(id)
    @attrs = attrs
    super()
  end

  # Renders the `nav`, yields the menu and appends the viewport when enabled.
  #
  # @yieldparam menu [Chadcn::NavigationMenu] the root, exposing the part helpers
  # @return [void]
  def view_template(&)
    previous = context[ROOT_KEY]
    dir = use_direction(@dir)
    context[ROOT_KEY] = {
      base: @id || "navigation-menu-#{next_sequence(SEQUENCE_KEY)}", items: 0, value: @value, orientation: @orientation, dir: dir
    }
    nav(**merge_attrs({
                        id: @id, aria: { label: "Main" }, dir: dir,
                        class: CLASSES,
                        data: {
                          orientation: @orientation, slot: "navigation-menu", viewport: @viewport.to_s, controller: "chadcn--navigation-menu",
                          chadcn__navigation_menu_value_value: @value, chadcn__navigation_menu_controlled_value: @controlled.to_s,
                          chadcn__navigation_menu_delay_duration_value: @delay_duration,
                          chadcn__navigation_menu_skip_delay_duration_value: @skip_delay_duration,
                          chadcn__navigation_menu_orientation_value: @orientation, chadcn__navigation_menu_dir_value: dir,
                          chadcn__navigation_menu_activation_mode_value: @activation_mode
                        }
                      }, @attrs)) do
      yield self if block_given?
      render Viewport.new if @viewport
    end
  ensure
    context[ROOT_KEY] = previous
  end

  # Shared by the parts: the root and item state of the current render.
  #
  # @api private
  module Support
    private

    def root_context
      context[ROOT_KEY] || raise(ArgumentError, "`#{self.class.name.unqualified}` must be used within `NavigationMenu`")
    end

    def item_context
      context[ITEM_KEY] || raise(ArgumentError, "`#{self.class.name.unqualified}` must be used within `NavigationMenu::Item`")
    end
  end

  # shadcn NavigationMenuList: the `ul` that holds the items, inside the indicator track.
  #
  # Also available as `menu.list` on the yielded menu.
  class List < Chadcn::Base
    include Support

    # Classes of the list.
    #
    # @api private
    CLASSES = "group flex flex-1 list-none items-center justify-center gap-1"

    # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
    #   the part's attributes are merged onto it. `true` is not supported.
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Renders the track `div` and the `ul` (or the `as_child` child) with the block as content.
    #
    # @yield the content of the element
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu}
    def view_template(&)
      root = root_context
      attrs = merge_attrs({ dir: root[:dir], class: CLASSES, data: { orientation: root[:orientation], slot: "navigation-menu-list" } },
                          @attrs)
      # Radix indicator track: the Indicator is mounted as the last child of this div.
      div(style: "position: relative;") do
        @as_child ? render_as_child(@as_child, **attrs, &) : ul(**attrs, &)
      end
    end
  end

  # shadcn NavigationMenuItem: the `li` that groups a trigger and its content under one value.
  #
  # Also available as `menu.item` on the yielded menu.
  # Renders only its `li`; it pushes the item value into the Phlex render context for Trigger and Content.
  # Radix mounts Content, the inner Viewport and the Indicator on the client, so those parts ship their markup in an
  # inert <template> (deviation: docs/shadcn-port/deviations/navigation-menu.json) that the controller clones.
  class Item < Chadcn::Base
    include Support

    # @param value [String, nil] value identifying the item (default: nil, an id from the root's counter is generated)
    # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
    #   the part's attributes are merged onto it. `true` is not supported.
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(value: nil, as_child: false, **attrs)
      @value = value&.to_s&.unless_blank
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Publishes the item state to the context and renders the `li` (or the `as_child` child) with the block as content.
    #
    # @yield the content of the element
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu}
    def view_template(&)
      root = root_context
      previous = context[ITEM_KEY]
      value = @value || "#{root[:base]}-item-#{root[:items] += 1}"
      context[ITEM_KEY] =
        { value: value, open: value == root[:value], trigger_id: "#{root[:base]}-trigger-#{value}",
          content_id: "#{root[:base]}-content-#{value}" }
      attrs = merge_attrs({ class: "relative", data: { slot: "navigation-menu-item" } }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : li(**attrs, &)
    ensure
      context[ITEM_KEY] = previous
    end
  end

  # shadcn NavigationMenuTrigger: the `button` that opens its item's content. Must be inside an {Item}.
  #
  # Also available as `menu.trigger` on the yielded menu.
  class Trigger < Chadcn::Base
    include Support

    # @param disabled [Boolean] disable the trigger (default: false)
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(disabled: false, **attrs)
      @disabled = disabled
      @attrs = attrs
      super()
    end

    # Renders the `button` with the block as label followed by the chevron icon.
    #
    # @yield the label of the trigger
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu::Item}
    def view_template
      item = item_context
      open = item[:open]
      button(**merge_attrs({
                             id: item[:trigger_id], disabled: (if @disabled
                                                                 true
                                                               end), class: cn(Chadcn::NavigationMenu.trigger_style, "group"),
                             aria: { expanded: open.to_s, controls: (item[:content_id] if open) },
                             data: {
                               state: open ? "open" : "closed", disabled: (@disabled ? "" : nil), slot: "navigation-menu-trigger", radix_collection_item: "",
                               chadcn__navigation_menu_value_param: item[:value], chadcn__navigation_menu_controls_param: item[:content_id]
                             }
                           }, @attrs)) do
        yield if block_given?
        plain " "
        render Chadcn::Icon.new("chevron-down",
                                class: "relative top-[1px] ml-1 size-3 transition duration-300 group-data-[state=open]:rotate-180", aria: { hidden: "true" })
      end
    end
  end

  # shadcn NavigationMenuContent: the panel of an item, shipped in an inert `template` that the controller clones.
  #
  # Also available as `menu.content` on the yielded menu.
  class Content < Chadcn::Base
    include Support

    # Classes of the content panel.
    #
    # @api private
    CLASSES = [
      "top-0 left-0 w-full p-2 pr-2.5 data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out md:absolute md:w-auto",
      "group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden group-data-[viewport=false]/navigation-menu:rounded-md group-data-[viewport=false]/navigation-menu:border group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:shadow group-data-[viewport=false]/navigation-menu:duration-200 **:data-[slot=navigation-menu-link]:focus:ring-0 **:data-[slot=navigation-menu-link]:focus:outline-none group-data-[viewport=false]/navigation-menu:data-[state=closed]:animate-out group-data-[viewport=false]/navigation-menu:data-[state=closed]:fade-out-0 group-data-[viewport=false]/navigation-menu:data-[state=closed]:zoom-out-95 group-data-[viewport=false]/navigation-menu:data-[state=open]:animate-in group-data-[viewport=false]/navigation-menu:data-[state=open]:fade-in-0 group-data-[viewport=false]/navigation-menu:data-[state=open]:zoom-in-95"
    ].freeze

    # @param force_mount [Boolean] keep the part mounted while closed (`data-force-mount`) (default: false)
    # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
    #   the part's attributes are merged onto it. `true` is not supported.
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(force_mount: false, as_child: false, **attrs)
      @force_mount = force_mount
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Markup of the mounted content; the controller adds data-motion, and data-state / pointer-events without a viewport.
    #
    # @yield the content of the element
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu} or a {NavigationMenu::Item}
    def view_template(&)
      root = root_context
      item = item_context
      attrs = merge_attrs({
                            id: item[:content_id], aria: { labelledby: item[:trigger_id] }, dir: root[:dir], class: cn(*CLASSES),
                            data: { orientation: root[:orientation], slot: "navigation-menu-content" }
                          }, @attrs)
      template(data: { chadcn__navigation_menu_target: "contentTemplate", value: item[:value], force_mount: (@force_mount ? "true" : nil) }) do
        @as_child ? render_as_child(@as_child, **attrs, &) : div(**attrs, &)
      end
    end
  end

  # shadcn NavigationMenuViewport: the shared container that hosts the open content (inert `template`).
  #
  # Rendered automatically by the root unless `viewport: false`; also available as `menu.viewport`.
  class Viewport < Chadcn::Base
    include Support

    # Classes of the viewport.
    #
    # @api private
    CLASSES = "origin-top-center relative mt-1.5 h-[var(--radix-navigation-menu-viewport-height)] w-full overflow-hidden rounded-md border bg-popover text-popover-foreground shadow data-[state=closed]:animate-out data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:zoom-in-90 md:w-[var(--radix-navigation-menu-viewport-width)]"

    # @param force_mount [Boolean] keep the part mounted while closed (`data-force-mount`) (default: false)
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(force_mount: false, **attrs)
      @force_mount = force_mount
      @attrs = attrs
      super()
    end

    # Renders the positioning `div` with the viewport clone source inside a `template`.
    #
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu}
    def view_template
      root = root_context
      div(class: "absolute top-full left-0 isolate z-50 flex justify-center") do
        template(data: { chadcn__navigation_menu_target: "viewportTemplate", force_mount: (@force_mount ? "true" : nil) }) do
          div(**merge_attrs({ class: CLASSES, data: { orientation: root[:orientation], slot: "navigation-menu-viewport" } }, @attrs))
        end
      end
    end
  end

  # shadcn NavigationMenuLink: the `a` of a menu entry.
  #
  # Also available as `menu.link` on the yielded menu.
  class Link < Chadcn::Base
    # Classes of the link.
    #
    # @api private
    CLASSES = "flex flex-col gap-1 rounded-sm p-2 text-sm transition-all outline-none hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 data-[active=true]:bg-accent/50 data-[active=true]:text-accent-foreground data-[active=true]:hover:bg-accent data-[active=true]:focus:bg-accent [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

    # @param active [Boolean] mark the link as the current page (`aria-current`, `data-active`) (default: false)
    # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
    #   the part's attributes are merged onto it. `true` is not supported.
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(active: false, as_child: false, **attrs)
      @active = active
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Renders the `a` (or the `as_child` child) with the block as content.
    #
    # @yield the content of the element
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({
                            class: CLASSES, aria: { current: (@active ? "page" : nil) },
                            data: { active: (@active ? "" : nil), slot: "navigation-menu-link", radix_collection_item: "" }
                          }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : a(**attrs, &)
    end
  end

  # shadcn NavigationMenuIndicator: the arrow under the active trigger (inert `template`, mounted by the controller).
  #
  # Also available as `menu.indicator` on the yielded menu.
  class Indicator < Chadcn::Base
    include Support

    # Classes of the indicator.
    #
    # @api private
    CLASSES = "top-full z-[1] flex h-1.5 items-end justify-center overflow-hidden data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:animate-in data-[state=visible]:fade-in"

    # @param force_mount [Boolean] keep the part mounted while closed (`data-force-mount`) (default: false)
    # @param attrs [Hash] HTML attributes for the element; `class:` is tailwind-merged over the defaults, `data:` and `aria:`
    #   are deep-merged (caller wins)
    def initialize(force_mount: false, **attrs)
      @force_mount = force_mount
      @attrs = attrs
      super()
    end

    # Renders the indicator clone source inside a `template`.
    # The controller sets data-state and the position style when it mounts the clone into the List track.
    #
    # @return [void]
    # @raise [ArgumentError] when rendered outside a {NavigationMenu}
    def view_template
      root = root_context
      template(data: { chadcn__navigation_menu_target: "indicatorTemplate", force_mount: (@force_mount ? "true" : nil) }) do
        div(**merge_attrs(
          { aria: { hidden: "true" }, class: CLASSES, data: { orientation: root[:orientation], slot: "navigation-menu-indicator" } }, @attrs
        )) do
          div(class: "relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md")
        end
      end
    end
  end
end
