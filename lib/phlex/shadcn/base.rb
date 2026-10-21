# frozen_string_literal: true

require "date" # Phlex::SGML::Attributes references Date without requiring it
require "securerandom"

using Phlex::Shadcn::Values::Refinements

# Parent of every Phlex::Shadcn component and part. Provides attribute merging (`**attrs`, `class:` through tailwind-merge,
# deep-merged `data:`/`aria:`), the Radix Slot merge behind `as_child:` and the generated yielded-root helpers
# (`root.header { ... }`, one per nested part; the README and docs/api-conventions.md describe them).
#
# Use its subclasses (the components) through their own API. Subclassing Base itself from application code is not a supported
# API before 1.0: every method on this class is plumbing for the components and is `@api private`.
class Phlex::Shadcn::Base < Phlex::HTML
  # @api private
  ELEMENT_METHODS = (Phlex::HTML::StandardElements.public_instance_methods +
                     Phlex::HTML::VoidElements.public_instance_methods).freeze

  DATA_ARIA = %w[data aria].freeze
  private_constant :DATA_ARIA

  # React DOM props written as snake_case kwargs (`tab_index:`) => the real HTML attribute (`tabindex`).
  # Without this Phlex dasherizes them into invalid names (`tab-index`). aria-*/data-* are handled separately.
  #
  # @api private
  DOM_ATTRIBUTES = %w[
    tabIndex formNoValidate readOnly maxLength minLength autoComplete autoFocus autoCapitalize autoCorrect autoSave
    spellCheck contentEditable crossOrigin encType formAction formEncType formMethod formTarget noValidate colSpan
    rowSpan srcSet srcDoc useMap dateTime inputMode enterKeyHint accessKey allowFullScreen playsInline hrefLang
    srcLang cellPadding cellSpacing charSet contextMenu controlsList disablePictureInPicture disableRemotePlayback
    frameBorder marginHeight marginWidth radioGroup referrerPolicy popoverTarget popoverTargetAction fetchPriority
    itemID itemProp itemRef itemScope itemType
  ].flat_map { |name| [ name, name.snake_case ].uniq.map { |spelling| [ spelling, name.downcase.to_sym ] } }
   .to_h
   .merge(%w[httpEquiv http_equiv].to_h { |spelling| [ spelling, :"http-equiv" ] })
   .merge(%w[acceptCharset accept_charset].to_h { |spelling| [ spelling, :"accept-charset" ] })
   .merge("className" => :class, "class_name" => :class, "htmlFor" => :for, "html_for" => :for)
   .freeze

  # Ruby 3.2+: runs for every constant assigned in a class body, nested `class Header < Base` included.
  # Defines `root.header(**attrs, &block)` == `render Root::Header.new(**attrs), &block`.
  # An HTML element name (`header`, `title`) may be shadowed on purpose: roots use `tag(:header)` internally.
  #
  # @api private
  def self.const_added(name)
    super
    part = begin
      const_get(name, false)
    rescue NameError
      # Zeitwerk is still registering this namespace's lazy parts and the part's file references a sibling that is not
      # registered yet; const_added fires again when the file assigns the constant. Any other NameError is a real bug.
      raise unless autoload?(name, false)

      nil
    end
    return unless part.is_a?(Class) && part < Phlex::Shadcn::Base

    helper = name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
    raise ArgumentError, "helper ##{helper} (from #{name}) would override a Ruby/Phlex API method" if reserved_helper_names.include?(helper)

    # Resolved at call time (not captured): `const_added` fires when the class is created, before its file has defined `initialize`.
    # Looked up on the namespace that owns the part, so subclasses of a root (`class AppTable < Phlex::Shadcn::Table`) keep the helpers.
    owner = self
    define_method(helper) { |**attrs, &block| render owner.const_get(name, false).new(**attrs), &block }
  end

  # @api private
  def self.reserved_helper_names
    (Object.public_instance_methods + Phlex::HTML.public_instance_methods) - ELEMENT_METHODS
  end

  # Slot accessors used by `render_as_child` on the child instance (components keep caller props in @attrs).
  #
  # @api private
  def as_child_attrs = @attrs || {}

  # `slot_class` is joined plainly in front of the child's own (cn-resolved) class, like Radix does.
  #
  # @api private
  def receive_slot(attrs, slot_class)
    @attrs = attrs
    @slot_class = slot_class
  end

  # Memoized TailwindMerge::Merger shared by every component (class-level).
  #
  # @api private
  def self.tw_merger
    @tw_merger ||= TailwindMerge::Merger.new
  end

  # Upper bound of memoized `cn` results. Callers may pass arbitrary class strings, so the cache is cleared when it fills
  # up (cheap, and a full cache means the workload is not repeating anyway).
  CN_CACHE_LIMIT = 2048
  private_constant :CN_CACHE_LIMIT

  # Created eagerly at load time: a lazy `||=` could build two locks under true parallelism or a thread switch.
  @cn_cache = {}
  @cn_cache_lock = Mutex.new

  # Process-wide memo of `cn` results, keyed by every input of the merge (defaults, variant, size and caller classes; the
  # slot class is joined outside `cn`). Values are frozen strings; guarded by a mutex for threaded servers and non-MRI runtimes.
  #
  # @api private
  def self.cn_cache = @cn_cache # rubocop:disable Style/TrivialAccessors -- attr_reader would hide the @api private tag from YARD

  # @api private
  def self.cn_cached(inputs)
    hit = @cn_cache_lock.synchronize { @cn_cache[inputs] }
    return hit if hit

    result = yield.freeze
    key = inputs.map { |input| input.nil? || input.frozen? ? input : input.dup.freeze }.freeze
    @cn_cache_lock.synchronize do
      @cn_cache.clear if @cn_cache.size >= CN_CACHE_LIMIT
      @cn_cache[key] = result
    end
    result
  end

  protected

  # Mirrors React's cn(...inputs) => twMerge(clsx(inputs)): strings, arrays, hashes (truthy keys) and nil, conflicts resolved.
  # Results for plain string/nil inputs (the component hot path) are memoized; the returned string is frozen.
  #
  # @api private
  def cn(*inputs)
    return merge_classes(inputs) unless inputs.all? { |input| input.nil? || input.instance_of?(String) }

    Phlex::Shadcn::Base.cn_cached(inputs) { merge_classes(inputs) }
  end

  # JSON for a data attribute, with the HTML-sensitive characters escaped (see Values.json).
  #
  # @api private
  def json(value) = Phlex::Shadcn::Values.json(value)

  # `"icon-sm"`, `:icon_sm` and `"icon_sm"` all become `"icon-sm"` (React variant keys).
  #
  # @api private
  def normalize_option(value)
    return if value.nil?

    string = value.is_a?(Symbol) ? value.name : value.to_s
    -(string.include?("_") ? string.tr("_", "-") : string)
  end

  # Ids for aria wiring: `ids("dialog-1")[:title]` => "dialog-1-title". Without a base a random one is used.
  #
  # @api private
  def ids(base = nil)
    base ||= "shadcn-#{SecureRandom.alphanumeric(6).downcase}"
    Hash.new { |_, part| "#{base}-#{part.to_s.tr('_', '-')}" }
  end

  # Component defaults + caller attrs: `data:`/`aria:` deep-merged (caller wins), `class` through `cn`
  # (caller wins on Tailwind conflicts), `data-action` descriptors and `data-controller` names concatenated
  # (defaults first; controller names de-duplicated, see dev/decisions/data-controller-merge.md).
  #
  # @api private
  def merge_attrs(defaults, attrs)
    defaults = canonical_attrs(defaults)
    attrs = canonical_attrs(attrs)
    merged = defaults.merge_deep(attrs)
    default_action = defaults.dig(:data, :action)
    caller_action = attrs.dig(:data, :action)
    if default_action || caller_action
      actions = [ default_action, caller_action ].reject_blank
      merged[:data] = (merged[:data] || {}).merge(action: actions.join(" ")) if actions.any?
    end
    merge_controllers(merged, defaults.dig(:data, :controller), attrs[:data])
    resolved = cn(defaults[:class], attrs[:class])
    css = @slot_class.nil? ? resolved : flatten_class_inputs([ @slot_class, resolved ]).join(" ")
    css.empty? ? merged.except(:class) : merged.merge(class: css)
  end

  # Radix `Slot`: renders `child` (a Phlex::Shadcn component instance, or a tag symbol) with `slot_attrs` merged in,
  # exactly like `@radix-ui/react-slot` mergeProps. NOT `merge_attrs`: no tailwind-merge here.
  #
  # @api private
  def render_as_child(child, **slot_attrs, &)
    slot = canonical_attrs(slot_attrs)
    if child.is_a?(Symbol) || child.is_a?(String)
      tag(child.to_sym, **slot, &)
    else
      child.receive_slot(slot_merge(slot.except(:class), canonical_attrs(child.as_child_attrs)), slot[:class])
      render(child, &)
    end
  end

  private

  # `data-controller` is a token list: the component's identifiers first, then the caller's, de-duplicated. A caller cannot
  # remove the component's controller (not even with `controller: nil`), like `data-action`. When the caller passed no
  # controller key `merge_deep` kept the default and nothing is allocated; otherwise the fresh `data` hash that
  # `merge_deep` built is replaced by a copy, never one the caller still holds.
  def merge_controllers(merged, default_controller, caller_data)
    return if default_controller.nil? || caller_data.nil? || !caller_data.key?(:controller)

    merged[:data] = merged[:data].merge(controller: controller_tokens(default_controller, caller_data[:controller]).join(" "))
  end

  # Whitespace-separated identifiers from strings, symbols, arrays or sets (blank entries dropped), in order, de-duplicated.
  def controller_tokens(first, second)
    tokens = []
    [ first, second ].each { |value| add_controller_tokens(tokens, value) }
    tokens.uniq
  end

  def add_controller_tokens(tokens, value)
    case value
    when nil then nil
    when Array, Set then value.each { |item| add_controller_tokens(tokens, item) }
    else tokens.concat(value.to_s.split)
    end
  end

  def merge_classes(inputs)
    flattened = flatten_class_inputs(inputs)
    return "" if flattened.empty?

    Phlex::Shadcn::Base.tw_merger.merge(flattened.join(" "))
  end

  # Recursively flattens class inputs with clsx semantics (String, Array, Hash with truthy keys, nil).
  def flatten_class_inputs(inputs)
    inputs.each_with_object([]) do |input, result|
      case input
      when String then result << input unless input.empty?
      when Array then result.concat(flatten_class_inputs(input))
      when Hash then input.each { |key, value| result << key.to_s if value }
      when nil then next
      else result << input.to_s
      end
    end
  end

  # Canonical shape: top-level keys as given (React DOM prop names mapped to HTML ones), `data`/`aria` always nested
  # hashes with underscored symbol keys (flat `"data-foo"` / `:"aria-label"` keys are folded in). Like React, boolean
  # aria/data values render as "true"/"false" (Phlex would render a bare attribute / drop it).
  def canonical_attrs(attrs)
    result = {}
    (attrs || {}).each do |key, value|
      flat = key.is_a?(Symbol) ? key.name : key.to_s
      group = (flat.start_with?("data-") && "data") || (flat.start_with?("aria-") && "aria")
      if group
        (result[group.to_sym] ||= {})[flat.delete_prefix("#{group}-").tr("-", "_").to_sym] = stringify_boolean(value)
      elsif DATA_ARIA.include?(flat)
        nested = (result[flat.to_sym] ||= {})
        (value || {}).each { |k, v| nested[k.to_s.tr("-", "_").to_sym] = stringify_boolean(v) }
      else
        result[DOM_ATTRIBUTES.fetch(flat, key)] = value
      end
    end
    result
  end

  def stringify_boolean(value)
    [ true, false ].include?(value) ? value.to_s : value
  end

  def slot_merge(slot, child)
    merged = slot.merge_deep(child) # child wins everything by default
    data = merged[:data] = (merged[:data] || {}).dup # never mutate a hash the caller or the child still holds
    actions = [ child.dig(:data, :action), slot.dig(:data, :action) ].reject_blank
    data[:action] = actions.join(" ") if actions.any?
    controllers = controller_tokens(slot.dig(:data, :controller), child.dig(:data, :controller))
    data[:controller] = controllers.join(" ") if controllers.any?
    merged.delete(:data) if data.empty?

    merged[:style] = merge_styles(slot[:style], child[:style]) if slot[:style] && child[:style]

    if child.dig(:aria, :describedby)
      ids = [ child.dig(:aria, :describedby), slot.dig(:aria, :describedby) ].reject_blank.flat_map { |i| i.to_s.split }.uniq
      merged[:aria] = merged[:aria].merge(describedby: ids.empty? ? nil : ids.join(" "))
    end
    merged
  end

  def merge_styles(slot_style, child_style)
    return slot_style.merge(child_style) if slot_style.is_a?(Hash) && child_style.is_a?(Hash)

    [ style_string(slot_style), style_string(child_style) ].join("; ")
  end

  def style_string(style)
    style.is_a?(Hash) ? style.map { |k, v| "#{k.to_s.tr('_', '-')}: #{v}" }.join("; ") : style.to_s.strip.chomp(";")
  end
end
