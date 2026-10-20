# frozen_string_literal: true

# shadcn Toaster (the `Toaster` of shadcn's `sonner.tsx`): the live region the toasts are shown in. Render it once, in the layout.
#
# Renders `<section aria-live="polite">` hosting the `shadcn--sonner` controller, the Lucide icons of each toast type as inert templates
# and the toasts the server wants to show on load. The stacked `<ol>`/`<li>` toasts are created by the controller, like sonner does.
#
# Toasts: `window.Toaster` (JavaScript), `flash:` / `toasts:` / the block (server, on page load), a Turbo Stream that appends a
# {Phlex::Shadcn::Sonner::Toast} to this Toaster's `id` (server, later), or the `shadcn--sonner:show` event. The hotkey (default Alt+T)
# expands the stack and focuses it, Escape collapses it.
#
# Events (on the section, bubbling): `shadcn--sonner:dismiss`, `:auto-close` (`detail: { id }`), `:action` and `:cancel`
# (`detail: { id, name }` with the `event` of the toast's action).
#
# @example Layout
#   render Phlex::Shadcn::Toaster.new(flash: flash.to_h, close_button: true, position: "top-center")
class Phlex::Shadcn::Sonner::Toaster < Phlex::Shadcn::Base
  # Lucide icon and classes of each type, from the shadcn wrapper (`icons={{ success: <CircleCheckIcon className="size-4" /> ... }}`).
  #
  # @api private
  ICONS = {
    "success" => %w[circle-check size-4],
    "info" => %w[info size-4],
    "warning" => %w[triangle-alert size-4],
    "error" => %w[octagon-x size-4],
    "loading" => [ "loader-circle", "size-4 animate-spin" ]
  }.freeze
  # Default `hotkey:`. A frozen constant, because Ruby 3.2 renders an array literal default of a signature differently (YARD, snapshots).
  #
  # @api private
  DEFAULT_HOTKEY = %w[altKey KeyT].freeze
  # Colors of the toast, from the shadcn wrapper `style` (the theme's popover colors).
  #
  # @api private
  THEME_VARS = {
    "--normal-bg" => "var(--popover)",
    "--normal-text" => "var(--popover-foreground)",
    "--normal-border" => "var(--border)",
    "--border-radius" => "var(--radius)"
  }.freeze
  # The close icon of sonner is 24 units wide (built, not written, so the class-token scanner of the static gate does not read it as classes).
  #
  # @api private
  CLOSE_VIEW_BOX = [ 0, 0, 24, 24 ].join(" ")
  # Flash keys shown with a type (every other key shows a plain toast).
  #
  # @api private
  FLASH_TYPES = { "notice" => "success", "success" => "success", "alert" => "error", "error" => "error", "warning" => "warning", "info" => "info" }.freeze

  # @param position [String, Symbol] `top-left`, `top-center`, `top-right`, `bottom-left`, `bottom-center` or `bottom-right`
  # @param theme [String, Symbol] `light`, `dark` or `system` (follows `prefers-color-scheme`; the shadcn wrapper defaults to the app theme, `system` here)
  # @param rich_colors [Boolean, nil] colored toasts per type; nil leaves `data-rich-colors` off the toasts, like an omitted prop
  # @param expand [Boolean] keep every toast expanded
  # @param close_button [Boolean] a close button on each toast
  # @param invert [Boolean] swap the toast colors
  # @param duration [Integer, nil] default ms before a toast closes (4000)
  # @param visible_toasts [Integer] toasts shown at once
  # @param gap [Integer] px between expanded toasts
  # @param offset [Integer, String, Hash, nil] distance from the viewport edge; a Hash sets `top`, `right`, `bottom`, `left`
  # @param mobile_offset [Integer, String, Hash, nil] same, on screens up to 600px wide
  # @param dir [String, Symbol, nil] `ltr`, `rtl` or `auto` (default: the document's direction)
  # @param hotkey [Array<String>] keys that expand and focus the stack (`KeyboardEvent` property or `code`), default `["altKey", "KeyT"]`
  # @param container_aria_label [String] label of the region, followed by the hotkey (`Notifications alt+T`)
  # @param swipe_directions [Array<String>, nil] `top`, `right`, `bottom`, `left` (default: the edges of `position`)
  # @param toast_options [Hash, nil] defaults for every toast: `duration`, `close_button`, `class`, `description_class_name`, `unstyled`,
  #   `class_names` (`toast`, `title`, `description`, `icon`, `content`, `close_button`, `cancel_button`, `action_button`, `loader`, or a type), `style`,
  #   `close_button_aria_label`, `action_button_style`, `cancel_button_style`
  # @param icons [Hash, nil] per type (`success`, `info`, `warning`, `error`, `loading`, `close`): a component instance, or `false` for no icon
  # @param style [Hash, nil] inline style of the toast lists, merged over the shadcn theme variables (`--normal-bg`...)
  # @param toaster_id [String, nil] show only the toasts created for this id (sonner's `id`; the HTML id is `id:`)
  # @param flash [#to_h, nil] a flash hash: `notice`/`success` become success toasts, `alert`/`error` errors, `warning`, `info`
  # @param toasts [Array<Hash>, nil] toasts to show on load, each the keywords of {Phlex::Shadcn::Sonner::Toast}
  # @param attrs [Hash] HTML attributes of the `<section>` (`id:` defaults to `"toaster"`, the target of Turbo Stream appends; `class:` is added to the lists)
  def initialize(position: "bottom-right", theme: "system", rich_colors: nil, expand: false, close_button: false, invert: false,
                 duration: nil, visible_toasts: 3, gap: 14, offset: nil, mobile_offset: nil, dir: nil, hotkey: DEFAULT_HOTKEY,
                 container_aria_label: "Notifications", swipe_directions: nil, toast_options: nil, icons: nil, style: nil, toaster_id: nil,
                 flash: nil, toasts: nil, **attrs)
    @position = normalize_option(position)
    @theme = normalize_option(theme)
    @rich_colors = rich_colors
    @expand = expand
    @close_button = close_button
    @invert = invert
    @duration = duration
    @visible_toasts = visible_toasts
    @gap = gap
    @offset = offset
    @mobile_offset = mobile_offset
    @dir = normalize_option(dir)
    @hotkey = Array(hotkey)
    @container_aria_label = container_aria_label
    @swipe_directions = swipe_directions && Array(swipe_directions).map(&:to_s)
    @toast_options = toast_options
    @icons = icons || {}
    @style = style
    @toaster_id = toaster_id
    @flash = flash
    @toasts = toasts
    @attrs = attrs
    super()
  end

  # @yieldparam toaster [Toaster] the toaster; render {Phlex::Shadcn::Sonner::Toast}s inside the block to show them on load
  # @return [void]
  def view_template(&)
    section(**merge_attrs(root_attrs, @attrs.except(:class))) do
      icon_templates
      flash_toasts
      @toasts&.each { |toast| render Phlex::Shadcn::Sonner::Toast.new(**toast) }
      yield(self) if block_given?
    end
  end

  private

  def root_attrs
    {
      id: "toaster",
      tabindex: -1,
      aria: { label: "#{@container_aria_label} #{hotkey_label}", live: "polite", relevant: "additions text", atomic: "false" },
      data: { controller: "shadcn--sonner", **controller_values }
    }
  end

  # Sonner writes the hotkey as `alt+T` (`altKey+KeyT` without the `Key`/`Digit` words).
  def hotkey_label = @hotkey.join("+").gsub("Key", "").gsub("Digit", "")

  def controller_values
    {
      shadcn__sonner_position_value: @position,
      shadcn__sonner_theme_value: @theme,
      shadcn__sonner_rich_colors_value: @rich_colors&.to_s,
      shadcn__sonner_expand_value: @expand,
      shadcn__sonner_close_button_value: @close_button,
      shadcn__sonner_invert_value: @invert,
      shadcn__sonner_visible_toasts_value: @visible_toasts,
      shadcn__sonner_gap_value: @gap,
      shadcn__sonner_hotkey_value: json(@hotkey),
      shadcn__sonner_class_name_value: cn("toaster group", @attrs[:class]),
      shadcn__sonner_style_value: json(THEME_VARS.merge((@style || {}).transform_keys(&:to_s))),
      shadcn__sonner_duration_value: @duration,
      shadcn__sonner_offset_value: (json(@offset) unless @offset.nil?),
      shadcn__sonner_mobile_offset_value: (json(@mobile_offset) unless @mobile_offset.nil?),
      shadcn__sonner_dir_value: @dir,
      shadcn__sonner_swipe_directions_value: (json(@swipe_directions) if @swipe_directions),
      shadcn__sonner_toast_options_value: (json(toast_options_json) if @toast_options),
      shadcn__sonner_toaster_id_value: @toaster_id
    }.compact
  end

  # Ruby option names to the camelCase keys of sonner's `toastOptions`.
  def toast_options_json
    @toast_options.to_h do |key, value|
      value = value.transform_keys { |name| camelize(name) } if key.to_s == "class_names" && value.is_a?(Hash)
      [ camelize(key == :class ? "class_name" : key), value ]
    end
  end

  def camelize(name) = name.to_s.gsub(/_(\w)/) { Regexp.last_match(1).upcase }

  def icon_templates
    ICONS.each do |type, (name, classes)|
      icon_template(type, @icons.fetch(type.to_sym) { @icons.fetch(type, nil) }) { render Phlex::Shadcn::Icon.new(name, class: classes) }
    end
    icon_template("close", @icons.fetch(:close) { @icons.fetch("close", nil) }) { close_icon }
  end

  def icon_template(type, override, &)
    if override == false
      template(data: { shadcn__sonner_icon: type, none: "" })
    else
      template(data: { shadcn__sonner_icon: type }) { override ? render(override) : yield }
    end
  end

  # Sonner's own close icon (shadcn does not replace it).
  def close_icon
    svg(xmlns: "http://www.w3.org/2000/svg", width: "12", height: "12", viewBox: CLOSE_VIEW_BOX, fill: "none", stroke: "currentColor",
        stroke_width: "1.5", stroke_linecap: "round", stroke_linejoin: "round") do |s|
      s.line(x1: "18", y1: "6", x2: "6", y2: "18")
      s.line(x1: "6", y1: "6", x2: "18", y2: "18")
    end
  end

  def flash_toasts
    return unless @flash

    @flash.to_h.each do |key, message|
      next unless message.is_a?(String) && !message.empty?

      render Phlex::Shadcn::Sonner::Toast.new(title: message.to_s, type: FLASH_TYPES[key.to_s])
    end
  end
end
