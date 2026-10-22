# frozen_string_literal: true

# shadcn CommandItem: one selectable option (`div`, `role="option"`). Selecting it (click or Enter) dispatches
# `shadcn--command:select` with `{ value }` on the item.
#
# The value is `value:` when given, else the item's text (the controller derives it). `value`, `keywords`, `disabled` and
# `force_mount` never reach the DOM as such; the controller reads `data-shadcn--command-*` attributes.
#
# @example
#   render(Chadcn::Command::Item.new(keywords: ["agenda"]) { "Calendar" })
class Chadcn::Command::Item < Chadcn::Base
  include Chadcn::Command::Support

  # Default of `keywords:` (cmdk's `[]`), frozen so the signature renders identically on every Ruby.
  KEYWORDS = [].freeze

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50 data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

  # @param value [String, nil] the item's value (matched by the search; default: its text)
  # @param keywords [Array<String>] extra strings the search also matches
  # @param disabled [Boolean] not selectable
  # @param force_mount [Boolean] keep the item visible whatever the search
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the `div`
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(value: nil, keywords: KEYWORDS, disabled: false, force_mount: false, as_child: false, **attrs)
    @value = value
    @keywords = keywords
    @disabled = disabled
    @force_mount = force_mount
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the item's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template(&)
    attrs = item_attrs(root_context)
    return render_as_child(@as_child, **attrs, &) if @as_child

    div(**attrs, &)
  end

  private

  def item_attrs(root)
    attrs = merge_attrs({ class: CLASSES, data: { slot: "command-item" } }, @attrs)
    with_forced(
      attrs, { id: next_id(root, :items), "cmdk-item": "", role: "option" },
      aria: { disabled: @disabled.to_s, selected: "false" }, data: state_data
    )
  end

  def state_data
    data = { disabled: @disabled.to_s, selected: "false" }
    data[:value] = @value.to_s.strip unless @value.nil?
    data[:shadcn__command_keywords] = json(@keywords.map { |keyword| keyword.to_s.strip }) unless @keywords.empty?
    data[:shadcn__command_force_mount] = "true" if @force_mount
    data
  end
end
