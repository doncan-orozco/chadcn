# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn TabsTrigger: Radix Trigger on a roving focus item.
#
# @example
#   tabs.trigger(value: "account", disabled: false) { "Account" }
class Chadcn::Tabs::Trigger < Chadcn::Base
  include Chadcn::Tabs::Support

  # Default Tailwind classes of the trigger button.
  #
  # @api private
  CLASSES = [
    "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-md border border-transparent px-2 py-1 text-sm font-medium whitespace-nowrap text-foreground/60 transition-all group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:justify-start hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-50 group-data-[variant=default]/tabs-list:data-[state=active]:shadow-sm group-data-[variant=line]/tabs-list:data-[state=active]:shadow-none dark:text-muted-foreground dark:hover:text-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
    "group-data-[variant=line]/tabs-list:bg-transparent group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent dark:group-data-[variant=line]/tabs-list:data-[state=active]:border-transparent dark:group-data-[variant=line]/tabs-list:data-[state=active]:bg-transparent",
    "data-[state=active]:bg-background data-[state=active]:text-foreground dark:data-[state=active]:border-input dark:data-[state=active]:bg-input/30 dark:data-[state=active]:text-foreground",
    "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity group-data-[orientation=horizontal]/tabs:after:inset-x-0 group-data-[orientation=horizontal]/tabs:after:bottom-[-5px] group-data-[orientation=horizontal]/tabs:after:h-0.5 group-data-[orientation=vertical]/tabs:after:inset-y-0 group-data-[orientation=vertical]/tabs:after:-right-1 group-data-[orientation=vertical]/tabs:after:w-0.5 group-data-[variant=line]/tabs-list:data-[state=active]:after:opacity-100"
  ].freeze

  # @param value [String, Symbol] the tab value, matched by the content with the same value
  # @param disabled [Boolean] disables the tab
  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the trigger (a `data-action` is kept ahead of the tab actions)
  def initialize(value:, disabled: false, as_child: false, **attrs)
    @value = value.to_s
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template(&)
    root = root_context
    selected = root[:value] == @value
    attrs = merge_attrs({
                          type: "button",
                          role: "tab",
                          id: "#{root[:base_id]}-trigger-#{@value}",
                          tabindex: -1,
                          disabled: (true if @disabled),
                          class: CLASSES,
                          aria: { selected:, controls: "#{root[:base_id]}-content-#{@value}" },
                          data: { state: selected ? "active" : "inactive", disabled: (@disabled ? "" : nil), orientation: root[:orientation],
                                  radix_collection_item: "", slot: "tabs-trigger", shadcn__tabs_target: "trigger", shadcn__tabs_item_value: @value }
                        }, @attrs)
    # Radix composes the consumer handlers first, then the tab logic: our actions go last.
    action = [ attrs.dig(:data, :action),
               "mousedown->shadcn--tabs#mousedown keydown->shadcn--tabs#keydown focus->shadcn--tabs#focus" ].reject_blank.join(" ")
    render_part(:button, @as_child, attrs.merge(data: attrs[:data].merge(action:)), &)
  end
end
