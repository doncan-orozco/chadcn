# frozen_string_literal: true

# shadcn Drawer (vaul over Radix Dialog). Spec: dev/port/specs/drawer.md. Behavior: controllers/chadcn/drawer_controller.js,
# which extends the dialog controller and adds vaul's drag-to-dismiss gesture, snap points and background scaling.
#
# vaul Root renders no element; the port renders one display: contents host that carries the Stimulus controller (a trigger
# cannot host it: zero, one or several triggers, or a controlled open). Portal children are shipped in an inert template and
# mounted into the body by the controller, like Radix mounts them only while open. vaul's Handle and NestedRoot are not
# exported by shadcn's drawer.tsx and are not ported.
#
# Root of the Drawer family. Renders one `display: contents` host element that carries the Stimulus controller.
# Parts are rendered with the explicit classes or with the helpers generated on the yielded root (one per part).
#
# @example Explicit form
#   render Chadcn::Drawer.new do
#     render Chadcn::Drawer::Trigger.new { "Open" }
#     render Chadcn::Drawer::Content.new do
#       render(Chadcn::Drawer::Title.new { "Title" })
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Drawer.new(direction: "right") do |drawer|
#     drawer.trigger { "Open" }
#     drawer.content { drawer.title { "Title" } }
#   end
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method trigger(**attrs, &block)
#   Same as `render Drawer::Trigger.new(**attrs), &block`.
# @!method portal(&block)
#   Same as `render Drawer::Portal.new, &block`.
# @!method overlay(**attrs, &block)
#   Same as `render Drawer::Overlay.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Drawer::Content.new(**attrs), &block`.
# @!method header(**attrs, &block)
#   Same as `render Drawer::Header.new(**attrs), &block`.
# @!method footer(**attrs, &block)
#   Same as `render Drawer::Footer.new(**attrs), &block`.
# @!method title(**attrs, &block)
#   Same as `render Drawer::Title.new(**attrs), &block`.
# @!method description(**attrs, &block)
#   Same as `render Drawer::Description.new(**attrs), &block`.
# @!method close(**attrs, &block)
#   Same as `render Drawer::Close.new(**attrs), &block`.
class Chadcn::Drawer < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_drawer_root
  # @api private
  PORTAL_KEY = :shadcn_drawer_portal
  # @api private
  SEQUENCE_KEY = :shadcn_drawer_sequence
  # @api private
  DIRECTIONS = %w[top bottom left right].freeze

  # @param open [Boolean, nil] controlled open state when not nil (user actions only dispatch open-change; the caller updates it)
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param direction [String, Symbol, nil] edge the drawer slides from: top, bottom (default), left or right
  # @param dismissible [Boolean] false ignores every request to close and disables the drag when there are no snap points
  # @param modal [Boolean] false renders no overlay and lets outside presses through
  # @param handle_only [Boolean] vaul only starts a drag from a Handle, which shadcn does not export: true turns the drag off
  # @param auto_focus [Boolean] focus the first tabbable element on open (vaul prevents it by default)
  # @param snap_points [Array<Float, String>, nil] fractions of the viewport and/or "<n>px" strings
  # @param active_snap_point [Float, String, nil] controlled snap point
  # @param fade_from_index [Integer, nil] first snap point with an overlay (default: the last one)
  # @param snap_to_sequential_point [Boolean] never skip snap points on a fast flick
  # @param close_threshold [Float] fraction of the drawer that has to be dragged away to close it
  # @param scroll_lock_timeout [Integer] milliseconds a scrolled drawer ignores a drag
  # @param should_scale_background [Boolean] scale the `[data-vaul-drawer-wrapper]` element while open
  # @param set_background_color_on_scale [Boolean] paint the body black while the background is scaled
  # @param no_body_styles [Boolean] leave the body styles alone (position fixed, background)
  # @param fixed [Boolean] keep the position when the mobile keyboard opens
  # @param nested [Boolean] kept for API parity
  # @param disable_prevent_scroll [Boolean] iOS only: prevent the page scroll while open
  # @param prevent_scroll_restoration [Boolean] Safari only: do not restore the scroll position when the URL changed
  # @param reposition_inputs [Boolean] adjust the drawer when the mobile keyboard opens
  # @param container [String, nil] CSS selector of the element the drawer is mounted in (default: body)
  # @param id [String, nil] id of the content (what the trigger controls); the other generated ids derive from it (`"x-title"`,
  #   `"x-description"`). Default `drawer-N`, numbered per request with the engine, per render without it
  # @param attrs [Hash] HTML attributes merged into the host element
  # @raise [ArgumentError] when direction is not one of top, bottom, left, right, container: is not a non-empty String, or id: is
  #   empty or contains whitespace, a double quote or a backslash
  def initialize(open: nil, default_open: false, direction: "bottom", dismissible: true, modal: true, handle_only: false,
                 auto_focus: false, snap_points: nil, active_snap_point: nil, fade_from_index: nil, snap_to_sequential_point: false,
                 close_threshold: 0.25, scroll_lock_timeout: 100, should_scale_background: false, set_background_color_on_scale: true,
                 no_body_styles: false, fixed: false, nested: false, disable_prevent_scroll: true, prevent_scroll_restoration: false,
                 reposition_inputs: true, container: nil, id: nil, **attrs)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @direction = (direction || "bottom").to_s
    raise ArgumentError, "direction must be one of #{DIRECTIONS.join(', ')}, got #{direction.inspect}" unless DIRECTIONS.include?(@direction)

    @snap_points = snap_points&.to_a
    @active_snap_point = active_snap_point
    @fade_from_index = fade_from_index || @snap_points&.length&.pred
    raise ArgumentError, "container must be a non-empty String selector, got #{container.inspect}" unless container.nil? || (container.is_a?(String) && !container.empty?)

    @container = container
    @id = validated_id(id)
    @options = { dismissible:, modal:, handle_only:, auto_focus:, snap_to_sequential_point:, close_threshold:, scroll_lock_timeout:,
                 should_scale_background:, set_background_color_on_scale:, no_body_styles:, fixed:, nested:, disable_prevent_scroll:,
                 prevent_scroll_restoration:, reposition_inputs: }
    @attrs = attrs
    super()
  end

  # @yieldparam drawer [Drawer] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = [ context[ROOT_KEY], context[PORTAL_KEY] ]
    base = @id || "drawer-#{next_sequence(SEQUENCE_KEY)}"
    root = { content_id: base, title_id: "#{base}-title", description_id: "#{base}-description", open: @open,
             direction: @direction, modal: @options[:modal], container: @container, snap_points: snap_points?,
             should_fade: should_fade?, animate: @controlled || !@open }
    context[ROOT_KEY] = root
    context[PORTAL_KEY] = nil
    div(**merge_attrs({ style: "display: contents", data: host_data(base) }, @attrs)) { yield self if block_given? }
  ensure
    context[ROOT_KEY], context[PORTAL_KEY] = previous
  end

  private

  def snap_points? = !@snap_points.nil? && !@snap_points.empty?

  # vaul useSnapPoints shouldFade (vaul:539) as it is while open, before any drag.
  def should_fade?
    return true unless @snap_points

    active = @active_snap_point.nil? ? @snap_points.first : @active_snap_point
    !@fade_from_index.nil? && @snap_points[@fade_from_index] == active
  end

  # Radix Dialog is always modal inside vaul, so the dialog controller's own modal value stays true; vaul's modal is its own value.
  def host_data(base)
    values = {
      open: @open, controlled: @controlled, modal: true, id: base, vaul_modal: @options[:modal], direction: @direction,
      dismissible: @options[:dismissible], handle_only: @options[:handle_only], auto_focus: @options[:auto_focus],
      snap_points: (json(@snap_points) if snap_points?), active_snap_point: @active_snap_point&.to_s,
      fade_from_index: @fade_from_index, snap_to_sequential_point: @options[:snap_to_sequential_point],
      close_threshold: @options[:close_threshold], scroll_lock_timeout: @options[:scroll_lock_timeout],
      should_scale_background: @options[:should_scale_background],
      set_background_color_on_scale: @options[:set_background_color_on_scale], no_body_styles: @options[:no_body_styles],
      fixed: @options[:fixed], nested: @options[:nested], disable_prevent_scroll: @options[:disable_prevent_scroll],
      prevent_scroll_restoration: @options[:prevent_scroll_restoration], reposition_inputs: @options[:reposition_inputs],
      container: @container
    }.compact
    values.to_h { |name, value| [ :"chadcn__drawer_#{name}_value", value.to_s ] }.merge(controller: "chadcn--drawer")
  end
end
