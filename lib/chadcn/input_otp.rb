# frozen_string_literal: true

# shadcn InputOTP (the React-only `input-otp` 1.5.0 library). Spec: dev/port/specs/input-otp.md. Behavior:
# controllers/chadcn/input_otp_controller.js. No JavaScript dependency: the Stimulus controller re-implements OTPInput's DOM and
# state machine.
#
# A one-time-code field: a transparent `<input>` covers the slots, which show its characters and the active position.
#
# @example
#   render Chadcn::InputOtp.new(max_length: 6, pattern: Chadcn::InputOtp::REGEXP_ONLY_DIGITS) do |otp|
#     otp.group do
#       3.times { |index| otp.slot(index: index) }
#     end
#     otp.separator
#     otp.group do
#       3.times { |index| otp.slot(index: index + 3) }
#     end
#   end
#
# Events (Stimulus `dispatch`, prefix `chadcn--input-otp:`, `detail: { value }`): `change` (every accepted change) and `complete`
# (the value reached `max_length`). A JS `pasteTransformer` is assigned on the controller: `controller.pasteTransformer = (text) => string`.
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method group(**attrs, &block)
#   Same as `render InputOtp::Group.new(**attrs), &block`.
# @!method slot(**attrs)
#   Same as `render InputOtp::Slot.new(**attrs)`.
# @!method separator(**attrs)
#   Same as `render InputOtp::Separator.new(**attrs)`.
class Chadcn::InputOtp < Chadcn::Base
  # @api private
  CONTEXT_KEY = :shadcn_input_otp_root

  # Tailwind classes of the container, as in the shadcn source.
  CONTAINER_CLASSES = "flex items-center gap-2 has-disabled:opacity-50"
  # Tailwind classes of the input, as in the shadcn source.
  CLASSES = "disabled:cursor-not-allowed"

  # The library's exported patterns (`REGEXP_ONLY_DIGITS` and friends).
  REGEXP_ONLY_DIGITS = "^\\d+$"
  REGEXP_ONLY_CHARS = "^[a-zA-Z]+$"
  REGEXP_ONLY_DIGITS_AND_CHARS = "^[a-zA-Z0-9]+$"

  # The library's `noScriptCSSFallback`, verbatim.
  NO_SCRIPT_CSS_FALLBACK = <<~CSS.chomp.prepend("\n").freeze
    [data-input-otp] {
      --nojs-bg: white !important;
      --nojs-fg: black !important;

      background-color: var(--nojs-bg) !important;
      color: var(--nojs-fg) !important;
      caret-color: var(--nojs-fg) !important;
      letter-spacing: .25em !important;
      text-align: center !important;
      border: 1px solid var(--nojs-fg) !important;
      border-radius: 4px !important;
      width: 100% !important;
    }
    @media (prefers-color-scheme: dark) {
      [data-input-otp] {
        --nojs-bg: black !important;
        --nojs-fg: white !important;
      }
    }
  CSS

  CONTAINER_STYLE = "position: relative; cursor: %<cursor>s; user-select: none; -webkit-user-select: none; pointer-events: none"
  WRAPPER_STYLE = "position: absolute; inset: 0px; pointer-events: none"
  INPUT_STYLE = "position: absolute; inset: 0px; width: 100%%; height: 100%%; display: flex; text-align: %<text_align>s; opacity: 1; " \
                "color: transparent; pointer-events: all; background: transparent; caret-color: transparent; " \
                "border: 0px solid transparent; outline: transparent solid 0px; box-shadow: none; line-height: 1; " \
                "letter-spacing: -0.5em; font-size: var(--root-height, 16px); font-family: monospace; font-variant-numeric: tabular-nums"
  private_constant :CONTAINER_STYLE, :WRAPPER_STYLE, :INPUT_STYLE

  # @param max_length [Integer] number of slots and the input's maxlength
  # @param value [String, nil] controlled value (nil: uncontrolled)
  # @param default_value [String, nil] initial value when uncontrolled
  # @param pattern [String, nil] JS regexp source every typed value must match (see REGEXP_ONLY_DIGITS)
  # @param placeholder [String, nil] rendered as aria-placeholder only
  # @param input_mode [String, Symbol] the input's inputmode
  # @param text_align [String, Symbol] "left", "center" or "right"
  # @param push_password_manager_strategy [String, Symbol] "increase-width", "experimental-no-flickering" or "none"
  # @param no_script_css_fallback [String, nil] CSS of the `<noscript>` fallback; nil renders none
  # @param nonce [String, nil] CSP nonce of the stylesheet the controller injects
  # @param container_class_name [String, nil] classes of the container, merged after the defaults
  # @param class [String, nil] classes of the input, merged after the defaults
  # @param attrs [Hash] HTML attributes of the input (`id:`, `name:`, `disabled:`, `aria:`, `data:`...)
  def initialize(max_length:, value: nil, default_value: nil, pattern: nil, placeholder: nil, input_mode: "numeric", text_align: "left",
                 push_password_manager_strategy: "increase-width", no_script_css_fallback: NO_SCRIPT_CSS_FALLBACK, nonce: nil,
                 container_class_name: nil, **attrs)
    @max_length = Integer(max_length)
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value).to_s
    @pattern = pattern
    @placeholder = placeholder
    @input_mode = normalize_option(input_mode)
    @text_align = normalize_option(text_align)
    @strategy = normalize_option(push_password_manager_strategy)
    @no_script_css_fallback = no_script_css_fallback
    @nonce = nonce
    @container_class_name = container_class_name
    @attrs = attrs
    super()
  end

  # @yieldparam input_otp [InputOtp] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = context[CONTEXT_KEY]
    context[CONTEXT_KEY] = { value: @value, max_length: @max_length }
    noscript { style { raw(safe(@no_script_css_fallback)) } } if @no_script_css_fallback
    div(**container_attrs) do
      yield self if block_given?
      div(style: WRAPPER_STYLE) { input(**input_attrs) }
    end
  ensure
    context[CONTEXT_KEY] = previous
  end

  private

  def disabled? = !(@attrs[:disabled].nil? || @attrs[:disabled] == false)

  def container_attrs
    {
      "data-input-otp-container": "true", translate: "no", style: Kernel.format(CONTAINER_STYLE, cursor: disabled? ? "default" : "text"),
      class: cn(CONTAINER_CLASSES, @container_class_name),
      data: {
        controller: "chadcn--input-otp",
        chadcn__input_otp_max_length_value: @max_length, chadcn__input_otp_controlled_value: @controlled.to_s,
        chadcn__input_otp_pattern_value: @pattern, chadcn__input_otp_push_password_manager_strategy_value: @strategy,
        chadcn__input_otp_nonce_value: @nonce
      }.compact
    }
  end

  # The library spreads its own attributes after the caller's, so the caller cannot override them.
  def input_attrs
    attrs = merge_attrs({ class: CLASSES, autocomplete: "one-time-code", spellcheck: "false", data: { slot: "input-otp" } }, @attrs)
    forced = { data: { input_otp: "true", chadcn__input_otp_target: "input" }, inputmode: @input_mode, pattern: @pattern,
               style: Kernel.format(INPUT_STYLE, text_align: @text_align), maxlength: @max_length, value: @value }
    forced[:data][:input_otp_placeholder_shown] = "true" if @value.empty?
    forced[:aria] = { placeholder: @placeholder } if @placeholder
    attrs.merge(forced) { |_key, caller_value, forced_value| caller_value.is_a?(Hash) ? caller_value.merge(forced_value) : forced_value }
  end

  # shadcn InputOTPGroup: a row of slots.
  class Group < Chadcn::Base
    CLASSES = "flex items-center"

    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template(&)
      div(**merge_attrs({ class: CLASSES, data: { slot: "input-otp-group" } }, @attrs), &)
    end
  end

  # shadcn InputOTPSlot: one character box. The controller keeps its character, `data-active` and fake caret in step with the input.
  class Slot < Chadcn::Base
    CLASSES = "relative flex h-9 w-9 items-center justify-center border-y border-r border-input text-sm shadow-xs transition-all outline-none first:rounded-l-md first:border-l last:rounded-r-md aria-invalid:border-destructive data-[active=true]:z-10 data-[active=true]:border-ring data-[active=true]:ring-[3px] data-[active=true]:ring-ring/50 data-[active=true]:aria-invalid:border-destructive data-[active=true]:aria-invalid:ring-destructive/20 dark:bg-input/30 dark:data-[active=true]:aria-invalid:ring-destructive/40"
    # The fake caret, shipped inert and mounted by the controller while the slot is active and empty.
    CARET = "pointer-events-none absolute inset-0 flex items-center justify-center"
    CARET_BAR = "h-4 w-px animate-caret-blink bg-foreground duration-1000"

    # @param index [Integer] position of the character this slot shows
    # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
    def initialize(index:, **attrs)
      @index = Integer(index)
      @attrs = attrs
      super()
    end

    # @return [void]
    # @raise [ArgumentError] when rendered outside InputOtp
    def view_template
      root = context[Chadcn::InputOtp::CONTEXT_KEY] or raise ArgumentError, "#{self.class.name} must be used within InputOtp"
      inside = @index < root[:max_length]
      defaults = { class: CLASSES, data: { slot: "input-otp-slot", active: ("false" if inside), chadcn__input_otp_target: "slot", chadcn__input_otp_index_value: @index } }
      div(**merge_attrs(defaults, @attrs)) do
        plain root[:value][@index] if inside && root[:value][@index]
        template(data: { chadcn__input_otp_target: "caret" }) { div(class: CARET) { div(class: CARET_BAR) } } if inside
      end
    end
  end

  # shadcn InputOTPSeparator.
  class Separator < Chadcn::Base
    # @param attrs [Hash] HTML attributes merged into the element
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @return [void]
    def view_template
      div(**merge_attrs({ data: { slot: "input-otp-separator" }, role: "separator" }, @attrs)) { render Chadcn::Icon.new("minus") }
    end
  end
end

# The React export name (`InputOTP`): the parity harness and ports of React code look the component up by it.
Chadcn::InputOTP = Chadcn::InputOtp
