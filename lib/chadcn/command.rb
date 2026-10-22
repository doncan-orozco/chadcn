# frozen_string_literal: true

# shadcn Command (the React-only `cmdk` library). Spec: dev/port/specs/command.md. Behavior: controllers/shadcn/command_controller.js.
# No JavaScript dependency: the Stimulus controller re-implements cmdk's DOM and state machine and ranks with the scorer primitive.
#
# Root of the Command family (a filterable, keyboard-driven list of actions). Renders the root `div`, the sr-only `label`, and
# carries the `shadcn--command` Stimulus controller. Parts are rendered with the explicit classes or with the helpers generated
# on the yielded root (one per part).
#
# @example Explicit form
#   render Chadcn::Command.new do
#     render Chadcn::Command::Input.new(placeholder: "Type a command or search...")
#     render Chadcn::Command::List.new do
#       render Chadcn::Command::Empty.new { "No results found." }
#       render Chadcn::Command::Group.new(heading: "Suggestions") do
#         render(Chadcn::Command::Item.new { "Calendar" })
#       end
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Command.new do |command|
#     command.input(placeholder: "Type a command or search...")
#     command.list do
#       command.empty { "No results found." }
#       command.group(heading: "Suggestions") { command.item { "Calendar" } }
#     end
#   end
#
# Events (Stimulus `dispatch`, prefix `shadcn--command:`): `value-change` (controlled `value:` only), `search-change` (the input)
# and `select` (an item). A JS `filter` function is assigned on the controller: `controller.filter = (value, search, keywords) => number`.
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method dialog(**attrs, &block)
#   Same as `render Command::Dialog.new(**attrs), &block`.
# @!method input(**attrs)
#   Same as `render Command::Input.new(**attrs)`.
# @!method list(**attrs, &block)
#   Same as `render Command::List.new(**attrs), &block`.
# @!method empty(**attrs, &block)
#   Same as `render Command::Empty.new(**attrs), &block`.
# @!method group(**attrs, &block)
#   Same as `render Command::Group.new(**attrs), &block`.
# @!method item(**attrs, &block)
#   Same as `render Command::Item.new(**attrs), &block`.
# @!method shortcut(**attrs, &block)
#   Same as `render Command::Shortcut.new(**attrs), &block`.
# @!method separator(**attrs)
#   Same as `render Command::Separator.new(**attrs)`.
class Chadcn::Command < Chadcn::Base
  # @api private
  CONTEXT_KEY = :shadcn_command_root
  # @api private
  SEQUENCE_KEY = :shadcn_command_sequence

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "flex h-full w-full flex-col overflow-hidden rounded-md bg-popover text-popover-foreground"

  # Classes the root receives inside Command::Dialog (shadcn's CommandDialog), verbatim.
  DIALOG_COMMAND_CLASSES = "**:data-[slot=command-input-wrapper]:h-12 [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground [&_[cmdk-group]]:px-2 [&_[cmdk-group]:not([hidden])_~[cmdk-group]]:pt-0 [&_[cmdk-input-wrapper]_svg]:h-5 [&_[cmdk-input-wrapper]_svg]:w-5 [&_[cmdk-input]]:h-12 [&_[cmdk-item]]:px-2 [&_[cmdk-item]]:py-3 [&_[cmdk-item]_svg]:h-5 [&_[cmdk-item]_svg]:w-5"

  # cmdk's inline style for the visually hidden label (cmdk 1.1.1 `Te`).
  LABEL_STYLE = "position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border-width: 0"
  private_constant :LABEL_STYLE

  # @param label [String, nil] text of the sr-only label
  # @param value [String, nil] controlled selected value (trimmed); the caller updates it on `value-change`
  # @param default_value [String, nil] initial selected value when uncontrolled (not trimmed)
  # @param should_filter [Boolean] filter and sort the items by the search (false: the caller filters)
  # @param loop [Boolean] wrap the keyboard selection around the ends
  # @param disable_pointer_selection [Boolean] hovering an item does not select it
  # @param vim_bindings [Boolean] Ctrl+n/j/p/k move the selection
  # @param attrs [Hash] HTML attributes merged into the root (class goes through tailwind-merge)
  def initialize(label: nil, value: nil, default_value: nil, should_filter: true, loop: false, disable_pointer_selection: false,
                 vim_bindings: true, **attrs)
    @label = label
    @controlled = !value.nil?
    @value = @controlled ? value.to_s.strip : default_value.to_s
    @should_filter = should_filter
    @loop = loop
    @disable_pointer_selection = disable_pointer_selection
    @vim_bindings = vim_bindings
    @attrs = attrs
    super()
  end

  # @yieldparam command [Command] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = context[CONTEXT_KEY]
    base = "command-#{context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1}"
    root = { base: base, items: 0, groups: 0 }
    context[CONTEXT_KEY] = root
    div(**merge_attrs(root_defaults, @attrs)) do
      label("cmdk-label": "", for: "#{base}-input", id: "#{base}-label", style: LABEL_STYLE) { plain @label if @label }
      yield self if block_given?
    end
  ensure
    context[CONTEXT_KEY] = previous
  end

  private

  def root_defaults
    {
      tabindex: "-1", "cmdk-root": "", class: CLASSES,
      data: {
        slot: "command", controller: "shadcn--command",
        shadcn__command_value_value: @value, shadcn__command_controlled_value: @controlled.to_s,
        shadcn__command_should_filter_value: @should_filter.to_s, shadcn__command_loop_value: @loop.to_s,
        shadcn__command_vim_bindings_value: @vim_bindings.to_s,
        shadcn__command_disable_pointer_selection_value: @disable_pointer_selection.to_s
      }
    }
  end
end
