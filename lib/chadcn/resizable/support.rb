# frozen_string_literal: true

# What the resizable parts share: React-style ids, the ordered style merge of the library and the group context.
#
# @api private
module Chadcn::Resizable::Support
  ORIENTATIONS = %w[horizontal vertical].freeze

  private

  def group_context
    context[Chadcn::Resizable::GROUP_KEY] or raise ArgumentError, "#{self.class.name} must be used within Resizable::PanelGroup"
  end

  # React `useId` (client format) is called once per Group, Panel and Handle even when `id` is given, then `id ?? useId()`.
  def resizable_id(given)
    generated = "_r_#{(next_sequence(Chadcn::Resizable::SEQUENCE_KEY) - 1).to_s(32)}_"
    given || generated
  end

  # The caller id as one id token (a Stimulus-safe, selector-safe string), or nil.
  def given_id(id) = id.nil? || id == false ? nil : validated_id(js_string(id))

  def touch_action(orientation) = orientation == "horizontal" ? "pan-y" : "pan-x"

  def choice(value, allowed, name)
    string = normalize_option(value)
    return string if allowed.include?(string)

    raise ArgumentError, "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end

  # JS `String(value)`: whole floats lose the fraction.
  def js_string(value)
    value.is_a?(Float) && value.finite? && value == value.floor ? value.to_i.to_s : value.to_s
  end

  # An object spread like the library's: later entries replace the value of an earlier key in place, new keys append, and a
  # nil value removes the property.
  def style_attr(*layers)
    merged = layers.each_with_object({}) { |layer, all| all.merge!(style_pairs(layer)) }
    merged.reject { |_property, value| value.nil? || value == "" }.map { |property, value| "#{property}: #{value};" }.join(" ")
  end

  def style_pairs(style)
    pairs = style.is_a?(Hash) ? style.to_h { |name, value| [ css_name(name), value ] } : parse_declarations(style.to_s)
    pairs.transform_values { |value| value.nil? ? nil : js_string(value) }
  end

  def css_name(name)
    name = name.to_s
    return name if name.start_with?("--")

    name.tr("_", "-").gsub(/([A-Z])/) { "-#{Regexp.last_match(1).downcase}" }.sub(/\Ams-/, "-ms-")
  end

  # `a: b; c: url(x;y)` => { "a" => "b", "c" => "url(x;y)" } (semicolons inside parentheses or quotes do not split).
  def parse_declarations(css)
    css.scan(/(?:[^;("']|\((?:[^)]*)\)|"[^"]*"|'[^']*')+/).each_with_object({}) do |declaration, pairs|
      name, value = declaration.split(":", 2)
      pairs[name.strip] = value.strip if value && !name.strip.empty?
    end
  end

  # The caller attrs minus the keys the library sets after `...props` (they always win over the caller).
  def without_forced(attrs, data: [], aria: [], keys: [])
    canonical = canonical_attrs(attrs)
    canonical[:data] = canonical[:data].except(*data) if canonical[:data]
    canonical[:aria] = canonical[:aria].except(*aria) if canonical[:aria]
    canonical.except(*keys)
  end
end
