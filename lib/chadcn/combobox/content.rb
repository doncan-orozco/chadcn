# frozen_string_literal: true

# shadcn ComboboxContent: the popup (Base UI Portal > Positioner > Popup). Base UI renders nothing while the popup is unmounted, so
# the markup ships in an inert `<template>`; the controller mounts it into a `body > div[data-base-ui-portal]` while open and positions it
# against the input (or the trigger, when the search field lives inside the popup, or `anchor:`).
#
# @example
#   render Chadcn::Combobox::Content.new do
#     render(Chadcn::Combobox::Empty.new { "No items found." })
#     render(Chadcn::Combobox::List.new) { |item| render(Chadcn::Combobox::Item.new(value: item) { item }) }
#   end
class Chadcn::Combobox::Content < Chadcn::Base
  include Chadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "group/combobox-content relative max-h-96 w-(--anchor-width) max-w-(--available-width) min-w-[calc(var(--anchor-width)+--spacing(7))] origin-(--transform-origin) overflow-hidden rounded-md bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 data-[chips=true]:min-w-(--anchor-width) data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 *:data-[slot=input-group]:m-1 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 *:data-[slot=input-group]:border-input/30 *:data-[slot=input-group]:bg-input/30 *:data-[slot=input-group]:shadow-none data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95"

  # @param side [String, Symbol] "top", "bottom", "left", "right", "inline-start" or "inline-end"
  # @param side_offset [Integer] distance from the anchor in px
  # @param align [String, Symbol] "start", "center" or "end"
  # @param align_offset [Integer] offset along the alignment axis in px
  # @param anchor [String, nil] CSS selector of the element to position against (React: an element or ref from `useComboboxAnchor`);
  #   also marks the popup `data-chips="true"`
  # @param attrs [Hash] HTML attributes merged into the popup (class goes through tailwind-merge)
  def initialize(side: "bottom", side_offset: 6, align: "start", align_offset: 0, anchor: nil, **attrs)
    @side = normalize_option(side)
    @side_offset = side_offset
    @align = normalize_option(align)
    @align_offset = align_offset
    @anchor = anchor
    @attrs = attrs
    super()
  end

  # @yield the popup content ({Combobox::Empty}, {Combobox::List}, and the search {Combobox::Input} in popup mode)
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&)
    model = root_model
    options = { side: @side, sideOffset: @side_offset, align: @align, alignOffset: @align_offset, anchor: @anchor }
    template(data: { chadcn__combobox_part: "content-template", chadcn__combobox_options: json(options) }) do
      # The Positioner is the element that gets `--anchor-width` & co. and the translate; the Popup sits inside it.
      div(role: "presentation", class: "isolate z-50", data: { chadcn__combobox_part: "positioner" }) do
        model.in_popup = true
        div(**popup_attrs(model), &)
        model.in_popup = false
      end
    end
  end

  private

  def popup_attrs(model)
    defaults = { tabindex: "-1", role: model.input_outside ? "presentation" : "dialog", class: CLASSES,
                 data: { slot: "combobox-content", chips: (!@anchor.nil?).to_s, chadcn__combobox_part: "popup" } }
    defaults[:id] = model.popup_id unless model.input_outside
    merge_attrs(defaults, @attrs)
  end
end
