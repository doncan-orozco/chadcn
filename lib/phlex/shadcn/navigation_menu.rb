# frozen_string_literal: true

# shadcn NavigationMenu over Radix NavigationMenu. Spec: docs/shadcn-port/specs/navigation-menu.md.
# Behavior lives in controllers/v2/navigation_menu_controller.js (hosted by the root `nav`).
#
# Item renders only its `li`; it pushes the item value into the Phlex render context for Trigger and Content.
# Radix mounts Content, the inner Viewport and the Indicator on the client, so those parts ship their markup in an
# inert <template> (deviation: docs/shadcn-port/deviations/navigation-menu.json) that the controller clones.
class Phlex::Shadcn::NavigationMenu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :v2_navigation_menu_root
  ITEM_KEY = :v2_navigation_menu_item
  SEQUENCE_KEY = :v2_navigation_menu_sequence
  ORIENTATIONS = %w[horizontal vertical].freeze

  CLASSES = "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"
  # React `navigationMenuTriggerStyle()` (cva without variants).
  TRIGGER_STYLE = "group inline-flex h-9 w-max items-center justify-center rounded-md bg-background px-4 py-2 text-sm font-medium transition-[color,box-shadow] outline-none hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 disabled:pointer-events-none disabled:opacity-50 data-[state=open]:bg-accent/50 data-[state=open]:text-accent-foreground data-[state=open]:hover:bg-accent data-[state=open]:focus:bg-accent"

  def self.trigger_style(**options) = new.send(:cn, TRIGGER_STYLE, options[:class])

  # value: non-nil is controlled (the server decides the open item, user actions only dispatch value-change).
  def initialize(viewport: true, value: nil, default_value: "", delay_duration: 200, skip_delay_duration: 300,
                 orientation: "horizontal", dir: nil, activation_mode: "automatic", **attrs)
    @viewport = viewport
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value).to_s
    @delay_duration = delay_duration
    @skip_delay_duration = skip_delay_duration
    @orientation = ORIENTATIONS.include?(orientation.to_s) ? orientation.to_s : "horizontal"
    @dir = dir
    @activation_mode = activation_mode.to_s
    @attrs = attrs
    super()
  end

  def view_template(&)
    previous = context[ROOT_KEY]
    dir = use_direction(@dir)
    context[ROOT_KEY] = { base: "navigation-menu-#{self.class.next_sequence(context)}", value: @value, orientation: @orientation, dir: dir }
    nav(**merge_attrs({
                        aria: { label: "Main" }, dir: dir,
                        class: CLASSES,
                        data: {
                          orientation: @orientation, slot: "navigation-menu", viewport: @viewport.to_s, controller: "v2--navigation-menu",
                          v2__navigation_menu_value_value: @value, v2__navigation_menu_controlled_value: @controlled.to_s,
                          v2__navigation_menu_delay_duration_value: @delay_duration, v2__navigation_menu_skip_delay_duration_value: @skip_delay_duration,
                          v2__navigation_menu_orientation_value: @orientation, v2__navigation_menu_dir_value: dir,
                          v2__navigation_menu_activation_mode_value: @activation_mode
                        }
                      }, @attrs)) do
      yield self if block_given?
      render Viewport.new if @viewport
    end
  ensure
    context[ROOT_KEY] = previous
  end

  # Per render counter (no SecureRandom): ids are only compared through their relations.
  def self.next_sequence(context) = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1

  # Shared by the parts: the root and item state of the current render.
  module Support
    private

    def root_context
      context[ROOT_KEY] || raise(ArgumentError, "`#{self.class.name.demodulize}` must be used within `NavigationMenu`")
    end

    def item_context
      context[ITEM_KEY] || raise(ArgumentError, "`#{self.class.name.demodulize}` must be used within `NavigationMenu::Item`")
    end
  end

  class List < Phlex::Shadcn::Base
    include Support

    CLASSES = "group flex flex-1 list-none items-center justify-center gap-1"

    def initialize(as_child: false, **attrs)
      @as_child = as_child
      @attrs = attrs
      super()
    end

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

  class Item < Phlex::Shadcn::Base
    include Support

    def initialize(value: nil, as_child: false, **attrs)
      @value = value&.to_s.presence
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      root = root_context
      previous = context[ITEM_KEY]
      value = @value || "#{root[:base]}-item-#{self.class.next_sequence(context)}"
      context[ITEM_KEY] =
        { value: value, open: value == root[:value], trigger_id: "#{root[:base]}-trigger-#{value}",
          content_id: "#{root[:base]}-content-#{value}" }
      attrs = merge_attrs({ class: "relative", data: { slot: "navigation-menu-item" } }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : li(**attrs, &)
    ensure
      context[ITEM_KEY] = previous
    end

    def self.next_sequence(context) = Phlex::Shadcn::NavigationMenu.next_sequence(context)
  end

  class Trigger < Phlex::Shadcn::Base
    include Support

    def initialize(disabled: false, **attrs)
      @disabled = disabled
      @attrs = attrs
      super()
    end

    def view_template
      item = item_context
      open = item[:open]
      button(**merge_attrs({
                             id: item[:trigger_id], disabled: (if @disabled
                                                                 true
                                                               end), class: cn(Phlex::Shadcn::NavigationMenu.trigger_style, "group"),
                             aria: { expanded: open.to_s, controls: (item[:content_id] if open) },
                             data: {
                               state: open ? "open" : "closed", disabled: (@disabled ? "" : nil), slot: "navigation-menu-trigger", radix_collection_item: "",
                               v2__navigation_menu_value_param: item[:value], v2__navigation_menu_controls_param: item[:content_id]
                             }
                           }, @attrs)) do
        yield if block_given?
        plain " "
        render Phlex::Shadcn::Icon.new("chevron-down",
                                       class: "relative top-[1px] ml-1 size-3 transition duration-300 group-data-[state=open]:rotate-180", aria: { hidden: "true" })
      end
    end
  end

  class Content < Phlex::Shadcn::Base
    include Support

    CLASSES = [
      "top-0 left-0 w-full p-2 pr-2.5 data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out md:absolute md:w-auto",
      "group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden group-data-[viewport=false]/navigation-menu:rounded-md group-data-[viewport=false]/navigation-menu:border group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:shadow group-data-[viewport=false]/navigation-menu:duration-200 **:data-[slot=navigation-menu-link]:focus:ring-0 **:data-[slot=navigation-menu-link]:focus:outline-none group-data-[viewport=false]/navigation-menu:data-[state=closed]:animate-out group-data-[viewport=false]/navigation-menu:data-[state=closed]:fade-out-0 group-data-[viewport=false]/navigation-menu:data-[state=closed]:zoom-out-95 group-data-[viewport=false]/navigation-menu:data-[state=open]:animate-in group-data-[viewport=false]/navigation-menu:data-[state=open]:fade-in-0 group-data-[viewport=false]/navigation-menu:data-[state=open]:zoom-in-95"
    ].freeze

    def initialize(force_mount: false, as_child: false, **attrs)
      @force_mount = force_mount
      @as_child = as_child
      @attrs = attrs
      super()
    end

    # Markup of the mounted content; the controller adds data-motion, and data-state / pointer-events without a viewport.
    def view_template(&)
      root = root_context
      item = item_context
      attrs = merge_attrs({
                            id: item[:content_id], aria: { labelledby: item[:trigger_id] }, dir: root[:dir], class: cn(*CLASSES),
                            data: { orientation: root[:orientation], slot: "navigation-menu-content" }
                          }, @attrs)
      template(data: { v2__navigation_menu_target: "contentTemplate", value: item[:value], force_mount: (@force_mount ? "true" : nil) }) do
        @as_child ? render_as_child(@as_child, **attrs, &) : div(**attrs, &)
      end
    end
  end

  class Viewport < Phlex::Shadcn::Base
    include Support

    CLASSES = "origin-top-center relative mt-1.5 h-[var(--radix-navigation-menu-viewport-height)] w-full overflow-hidden rounded-md border bg-popover text-popover-foreground shadow data-[state=closed]:animate-out data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:zoom-in-90 md:w-[var(--radix-navigation-menu-viewport-width)]"

    def initialize(force_mount: false, **attrs)
      @force_mount = force_mount
      @attrs = attrs
      super()
    end

    def view_template
      root = root_context
      div(class: "absolute top-full left-0 isolate z-50 flex justify-center") do
        template(data: { v2__navigation_menu_target: "viewportTemplate", force_mount: (@force_mount ? "true" : nil) }) do
          div(**merge_attrs({ class: CLASSES, data: { orientation: root[:orientation], slot: "navigation-menu-viewport" } }, @attrs))
        end
      end
    end
  end

  class Link < Phlex::Shadcn::Base
    CLASSES = "flex flex-col gap-1 rounded-sm p-2 text-sm transition-all outline-none hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 data-[active=true]:bg-accent/50 data-[active=true]:text-accent-foreground data-[active=true]:hover:bg-accent data-[active=true]:focus:bg-accent [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

    def initialize(active: false, as_child: false, **attrs)
      @active = active
      @as_child = as_child
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({
                            class: CLASSES, aria: { current: (@active ? "page" : nil) },
                            data: { active: (@active ? "" : nil), slot: "navigation-menu-link", radix_collection_item: "" }
                          }, @attrs)
      @as_child ? render_as_child(@as_child, **attrs, &) : a(**attrs, &)
    end
  end

  class Indicator < Phlex::Shadcn::Base
    include Support

    CLASSES = "top-full z-[1] flex h-1.5 items-end justify-center overflow-hidden data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:animate-in data-[state=visible]:fade-in"

    def initialize(force_mount: false, **attrs)
      @force_mount = force_mount
      @attrs = attrs
      super()
    end

    # The controller sets data-state and the position style when it mounts the clone into the List track.
    def view_template
      root = root_context
      template(data: { v2__navigation_menu_target: "indicatorTemplate", force_mount: (@force_mount ? "true" : nil) }) do
        div(**merge_attrs(
          { aria: { hidden: "true" }, class: CLASSES, data: { orientation: root[:orientation], slot: "navigation-menu-indicator" } }, @attrs
        )) do
          div(class: "relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md")
        end
      end
    end
  end
end
