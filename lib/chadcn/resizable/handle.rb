# frozen_string_literal: true

# shadcn ResizableHandle over react-resizable-panels `Separator`: the draggable, focusable divider between two panels.
# ARIA values (`aria-controls`, `aria-valuenow`, ...) are written by the group controller once the layout is known.
#
# @example
#   render Chadcn::Resizable::Handle.new(with_handle: true)
class Chadcn::Resizable::Handle < Chadcn::Base
  include Chadcn::Resizable::Support

  # Classes of the separator, verbatim from the oracle.
  #
  # @api private
  CLASSES = "relative flex w-px items-center justify-center bg-border after:absolute after:inset-y-0 after:left-1/2 after:w-1 after:-translate-x-1/2 focus-visible:ring-1 focus-visible:ring-ring focus-visible:ring-offset-1 focus-visible:outline-hidden aria-[orientation=horizontal]:h-px aria-[orientation=horizontal]:w-full aria-[orientation=horizontal]:after:left-0 aria-[orientation=horizontal]:after:h-1 aria-[orientation=horizontal]:after:w-full aria-[orientation=horizontal]:after:translate-x-0 aria-[orientation=horizontal]:after:-translate-y-1/2 [&[aria-orientation=horizontal]>div]:rotate-90"
  # Classes of the grip.
  #
  # @api private
  GRIP_CLASSES = "z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border"

  # Stimulus actions of the separator (keyboard resizing and focus tracking), merged before a caller `data-action`.
  #
  # @api private
  ACTIONS = "keydown->chadcn--resizable#keydown focus->chadcn--resizable#focus blur->chadcn--resizable#blur"

  # Data keys the library owns on the separator (the caller cannot override them; `action` stays mergeable).
  #
  # @api private
  WIRING_KEYS = %i[chadcn__resizable_target chadcn__resizable_disable_double_click].freeze

  # @param with_handle [Boolean] renders the grip
  # @param disabled [Boolean] not focusable, not draggable, not resizable by keyboard
  # @param disable_double_click [Boolean] a double click does not reset a panel to its default size
  # @param preview [Chadcn::Base, nil] component shown instead of the handle clone while dragging with
  #   `resize_preview_mode: "separator"`
  # @param id [String, Integer, nil] element id; a React-style id is generated without it
  # @param style [String, Hash, nil] merged where the library merges it
  # @param attrs [Hash] HTML attributes for the separator div (`class:` merged last)
  def initialize(with_handle: false, disabled: false, disable_double_click: false, preview: nil, id: nil, style: nil, **attrs)
    @with_handle = with_handle ? true : false
    @disabled = disabled ? true : false
    @disable_double_click = disable_double_click ? true : false
    @preview = preview
    @id = given_id(id)
    @style = style
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template
    group = group_context
    id = resizable_id(@id)
    div(**handle_attrs(id, group)) do
      grip if @with_handle
      template(data: { chadcn__resizable_target: "preview" }) { render @preview } if @preview
    end
  end

  private

  def handle_attrs(id, group)
    merge_attrs({
                  class: CLASSES,
                  aria: { disabled: ("true" if @disabled), orientation: (group[:orientation] == "horizontal" ? "vertical" : "horizontal") },
                  data: { slot: "resizable-handle", separator: (@disabled ? "disabled" : "inactive"), testid: id,
                          chadcn__resizable_target: "handle", action: ACTIONS,
                          chadcn__resizable_disable_double_click: ("true" if @disable_double_click) },
                  id:,
                  role: "separator",
                  style: style_attr({ "flex-basis" => "auto", "cursor" => (@disabled && !group[:disable_cursor] ? "not-allowed" : nil) }, @style,
                                    { "flex-grow" => "0", "flex-shrink" => "0", "touch-action" => "none" }),
                  tabindex: (@disabled ? nil : 0)
                }, without_forced(@attrs, data: %i[separator testid] + WIRING_KEYS,
                                          aria: %i[controls disabled orientation valuemax valuemin valuenow],
                                          keys: %i[id role style tabindex]))
  end

  def grip
    div(class: GRIP_CLASSES) { render Chadcn::Icon.new("grip-vertical", class: "size-2.5") }
  end
end
