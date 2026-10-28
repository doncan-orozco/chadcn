# frozen_string_literal: true

require "date" # Phlex::SGML::Attributes references Date without requiring it
require "securerandom"

using Chadcn::Values::Refinements

# Parent of every Chadcn component and part. Provides attribute merging (`**attrs`, `class:` through tailwind-merge,
# deep-merged `data:`/`aria:`), the Radix Slot merge behind `as_child:` and the generated yielded-root helpers
# (`root.header { ... }`, one per nested part; the README and docs/api-conventions.md describe them).
#
# Use its subclasses (the components) through their own API. Subclassing Base itself from application code is not a supported
# API before 1.0: every method on this class is plumbing for the components and is `@api private`.
class Chadcn::Base < Phlex::HTML
  # @api private
  ELEMENT_METHODS = (Phlex::HTML::StandardElements.public_instance_methods +
                     Phlex::HTML::VoidElements.public_instance_methods).freeze

  DATA_ARIA = %w[data aria].freeze
  private_constant :DATA_ARIA

  # One id token: not empty, no whitespace, no double quote, no backslash (see #validated_id).
  ID_TOKEN = /\A[^\s"\\]+\z/
  private_constant :ID_TOKEN

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
    # Zeitwerk registers a directory without a file (Chart::Scale, Chart::Shape) as an autoload of the directory path, and Ruby
    # fires const_added on that very call. Such a namespace is a plain module, never a part, and `const_get` would try to require
    # the directory while the root is still registering its lazy parts. A part always autoloads from its .rb file.
    return if (path = autoload?(name, false)) && File.directory?(path)

    part = begin
      const_get(name, false)
    rescue NameError
      # Zeitwerk is still registering this namespace's lazy parts and the part's file references a sibling that is not
      # registered yet; const_added fires again when the file assigns the constant. Any other NameError is a real bug.
      raise unless autoload?(name, false)

      nil
    end
    return unless part.is_a?(Class) && part < Chadcn::Base

    helper = name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
    raise ArgumentError, "helper ##{helper} (from #{name}) would override a Ruby/Phlex API method" if reserved_helper_names.include?(helper)

    # Resolved at call time (not captured): `const_added` fires when the class is created, before its file has defined `initialize`.
    # Looked up on the namespace that owns the part, so subclasses of a root (`class AppTable < Chadcn::Table`) keep the helpers.
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

  # Process-wide state (the merger, the `cn` cache and its lock) is held in private constants of `Base`, not in class-level
  # instance variables: constants are looked up through inheritance, so every subclass shares the ONE instance on purpose
  # (the results are pure functions of their inputs) and `Subclass.tw_merger` can never see its own empty per-class variable.
  # All of it is created eagerly at load time: a lazy `||=` can build two mergers or two locks when threads race on first use.

  # The merger is thread-safe itself (its internal LRU cache is a `LruRedux::ThreadSafeCache`).
  #
  # tailwind_merge 1.5.6 maps the overflow-y group to the overscroll scale (auto/contain/none), so `overflow-y-auto overflow-y-scroll`
  # do not conflict. The group is fixed to the overflow scale here; this config can go when the gem fixes it.
  OVERFLOW_SCALE = %w[auto hidden clip visible scroll].freeze
  private_constant :OVERFLOW_SCALE
  TW_MERGER = TailwindMerge::Merger.new(
    config: { class_groups: TailwindMerge::Config::DEFAULTS[:class_groups].merge("overflow-y" => [ { "overflow-y" => OVERFLOW_SCALE } ]) }
  )
  private_constant :TW_MERGER

  # Upper bound of memoized `cn` results. Callers may pass arbitrary class strings, so the cache is cleared when it fills
  # up (cheap, and a full cache means the workload is not repeating anyway).
  CN_CACHE_LIMIT = 2048
  private_constant :CN_CACHE_LIMIT

  CN_CACHE = {} # rubocop:disable Style/MutableConstant -- the memo itself; only touched while holding CN_CACHE_LOCK
  CN_CACHE_LOCK = Mutex.new
  private_constant :CN_CACHE, :CN_CACHE_LOCK

  # The TailwindMerge::Merger shared by every component (built at load time).
  #
  # @api private
  def self.tw_merger = TW_MERGER

  # Frozen point-in-time copy of the process-wide memo of `cn` results (keys are every input of the merge: defaults, variant,
  # size and caller classes; the slot class is joined outside `cn`). Values are frozen strings. The live hash is never
  # exposed: it is read and written only while holding the mutex (threaded servers, non-MRI runtimes). For the gem's own tests.
  #
  # @api private
  # @return [Hash{Array<String, nil> => String}]
  def self.cn_cache = CN_CACHE_LOCK.synchronize { CN_CACHE.dup.freeze }

  # Empties the memo while holding the mutex. For the gem's own tests.
  #
  # @api private
  # @return [void]
  def self.clear_cn_cache
    CN_CACHE_LOCK.synchronize { CN_CACHE.clear }
    nil
  end

  # @api private
  def self.cn_cached(inputs)
    hit = CN_CACHE_LOCK.synchronize { CN_CACHE[inputs] }
    return hit if hit

    result = yield.freeze
    key = inputs.map { |input| input.nil? || input.frozen? ? input : input.dup.freeze }.freeze
    CN_CACHE_LOCK.synchronize do
      CN_CACHE.clear if CN_CACHE.size >= CN_CACHE_LIMIT
      CN_CACHE[key] = result
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

    Chadcn::Base.cn_cached(inputs) { merge_classes(inputs) }
  end

  # JSON for a data attribute, with the HTML-sensitive characters escaped (see Values.json).
  #
  # @api private
  def json(value) = Chadcn::Values.json(value)

  # `"icon-sm"`, `:icon_sm` and `"icon_sm"` all become `"icon-sm"` (React variant keys).
  #
  # @api private
  def normalize_option(value)
    return if value.nil?

    string = value.is_a?(Symbol) ? value.name : value.to_s
    -(string.include?("_") ? string.tr("_", "-") : string)
  end

  # Next number of the counter `key` behind the generated ids of a root (`"dialog-#{next_sequence(SEQUENCE_KEY)}"`): per request
  # with the engine, per render otherwise (Chadcn::Sequence).
  #
  # @api private
  def next_sequence(key) = Chadcn::Sequence.next(context, key)

  # The `id:` a root was given, as a String, or nil when the root generates one. It names an element (HoverCard and
  # Tooltip::Provider use it as a key, not as an element id; ContextMenu uses it as a key and names the content only when given;
  # Sidebar::Provider also uses it as the sidebar's name) and seeds the other ids where the root has any (`"#{id}-title"`), which
  # go into aria id lists and the controllers' attribute selectors, so it is one token: not empty, no whitespace, no double quote,
  # no backslash.
  #
  # @api private
  # @param id [String, Symbol, nil, false]
  # @return [String, nil]
  # @raise [ArgumentError] when the id cannot be one id token
  def validated_id(id)
    return if id.nil? || id == false

    string = id.is_a?(Symbol) ? id.name : id.to_s
    return string if ID_TOKEN.match?(string)

    raise ArgumentError, "id: must be a non-empty string without whitespace, double quotes or backslashes (got #{id.inspect})"
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

  # Radix `Slot`: renders `child` (a Chadcn component instance, or a tag symbol) with `slot_attrs` merged in,
  # exactly like `@radix-ui/react-slot` mergeProps. NOT `merge_attrs`: no tailwind-merge here.
  #
  # @api private
  def render_as_child(child, **slot_attrs, &)
    slot = canonical_attrs(slot_attrs)
    if child.is_a?(Symbol) || child.is_a?(String)
      tag(child.to_sym, **normalize_slot_controller(slot), &)
    else
      child.receive_slot(slot_merge(slot.except(:class), canonical_attrs(child.as_child_attrs)), slot[:class])
      render(child, &)
    end
  end

  private

  # `data-controller` is a token list: the component's identifiers first, then the caller's, de-duplicated. A caller cannot
  # remove the component's controller (not even with `controller: nil`), like `data-action`. The caller's value is normalized
  # (strings, symbols, arrays, sets; whitespace split) whether or not the component has a controller of its own. Without a
  # caller `controller:` key nothing is allocated; otherwise the `data` hash is replaced by a copy, never one the caller holds.
  def merge_controllers(merged, default_controller, caller_data)
    return if caller_data.nil? || !caller_data.key?(:controller)

    merged[:data] = with_controllers(merged[:data], controller_tokens(default_controller, caller_data[:controller]))
  end

  # Whitespace-separated identifiers from strings, symbols, arrays or sets (nil, false and blank entries dropped), in order, de-duplicated.
  def controller_tokens(first, second)
    tokens = []
    add_controller_tokens(tokens, first)
    add_controller_tokens(tokens, second)
    tokens.uniq!
    tokens
  end

  def add_controller_tokens(tokens, value)
    case value
    when nil, false then nil
    when Array, Set then value.each { |item| add_controller_tokens(tokens, item) }
    else tokens.concat(value.to_s.split)
    end
  end

  def merge_classes(inputs)
    flattened = flatten_class_inputs(inputs)
    return "" if flattened.empty?

    Chadcn::Base.tw_merger.merge(flattened.join(" "))
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
        name = flat.delete_prefix("#{group}-").tr("-", "_").to_sym
        (result[group.to_sym] ||= {})[name] = canonical_value(group, name, value)
      elsif DATA_ARIA.include?(flat)
        nested = (result[flat.to_sym] ||= {})
        (value || {}).each do |k, v|
          name = k.to_s.tr("-", "_").to_sym
          nested[name] = canonical_value(flat, name, v)
        end
      else
        result[DOM_ATTRIBUTES.fetch(flat, key)] = value
      end
    end
    result
  end

  # `data-controller` is a token list, so `false` must reach the token normalizer (and be dropped) instead of becoming "false".
  def canonical_value(group, name, value)
    group == "data" && name == :controller ? value : stringify_boolean(value)
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
    if controllers.empty?
      data.delete(:controller)
    else
      data[:controller] = controllers.join(" ")
    end
    merged.delete(:data) if data.empty?

    merged[:style] = merge_styles(slot[:style], child[:style]) if slot[:style] && child[:style]

    if child.dig(:aria, :describedby)
      ids = [ child.dig(:aria, :describedby), slot.dig(:aria, :describedby) ].reject_blank.flat_map { |i| i.to_s.split }.uniq
      merged[:aria] = merged[:aria].merge(describedby: ids.empty? ? nil : ids.join(" "))
    end
    merged
  end

  # A copy of `data` with the controller tokens written (or the key removed when there are none); never mutates `data`.
  def with_controllers(data, tokens)
    tokens.empty? ? data.except(:controller) : data.merge(controller: tokens.join(" "))
  end

  # A bare tag has no component controller to merge with, but the caller's token list is still normalized.
  def normalize_slot_controller(slot)
    return slot unless slot[:data]&.key?(:controller)

    data = with_controllers(slot[:data], controller_tokens(nil, slot[:data][:controller]))
    data.empty? ? slot.except(:data) : slot.merge(data: data)
  end

  def merge_styles(slot_style, child_style)
    return slot_style.merge(child_style) if slot_style.is_a?(Hash) && child_style.is_a?(Hash)

    [ style_string(slot_style), style_string(child_style) ].join("; ")
  end

  def style_string(style)
    style.is_a?(Hash) ? style.map { |k, v| "#{k.to_s.tr('_', '-')}: #{v}" }.join("; ") : style.to_s.strip.chomp(";")
  end
end
