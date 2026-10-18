# frozen_string_literal: true

# Renders a scenario `tree` with the V2 components, applying .ai/skills/shadcn-port/references/api-mapping.md.
# Mirror of gems/phlex-shadcn/dev/react-shadcn-catalog/src/parity/Harness.tsx; both sides must read the tree with the same rules:
#   - c "_a", "_div"... (underscore + lowercase): raw HTML element; props become attributes
#   - c "_Probe"...     (underscore + capital): harness stub in ShadcnParity
#   - c "DialogTrigger": Phlex::Shadcn::Dialog::Trigger (root prefix stripped); "Button" -> Phlex::Shadcn::Button
#   - children: strings are text; a string starting with "<icon:name>" renders that icon (rest is text)
#   - asChild: true: the single child node becomes the `as_child:` instance and its children the content
# dx: "helpers" renders nested parts through the YIELDED root (`root.header { ... }`) instead of `Root::Header.new`.
class ShadcnParity::TreeRenderer < Phlex::HTML
  class Error < StandardError; end

  ICON = /\A<icon:([\w-]+)>/
  PARITY_ROOTS = %w[Probe ProbeGroup].freeze
  Target = Struct.new(:klass, :root, :helper)

  def initialize(tree:, component: nil, dx: nil)
    @tree = tree
    @primary = component.to_s.delete_prefix("_").tr("-", "_").camelize.presence
    @dx = dx.to_s == "helpers"
    super()
  end

  def view_template
    render_node(@tree, {})
  end

  private

  def render_node(node, roots)
    name = node.fetch("c")
    return render_raw(node, roots) if name.match?(/\A_[a-z]/)

    target = resolve(name)
    props = component_props(node["props"])
    props[:as_child] = as_child_instance(node, roots) if node.dig("props", "asChild") == true
    content = props.key?(:as_child) ? as_child_node(node)["children"] : node["children"]

    if @dx && target.root && roots[target.root]
      roots[target.root].public_send(target.helper, **props) { render_children(content, roots) }
    elsif @dx && target.root.nil?
      render(target.klass.new(**props)) { |root| render_children(content, root.is_a?(target.klass) ? roots.merge(target.klass => root) : roots) }
    else
      render(target.klass.new(**props)) { render_children(content, roots) }
    end
  end

  def render_raw(node, roots)
    name = node["c"].delete_prefix("_")
    node = raw_value_semantics(name, node)
    render(ShadcnParity::RawElement.new(name, **raw_attrs(node["props"]))) do
      render_children(node["children"], roots)
    end
  end

  # React DOM value props on a one-shot render (`value` wins over `defaultValue`, same for checked):
  # input -> value attribute, textarea -> text content, select -> matching <option> gets `selected`.
  def raw_value_semantics(name, node)
    props = (node["props"] || {}).dup
    value = props.key?("value") ? props["value"] : props["defaultValue"]
    checked = props.key?("checked") ? props["checked"] : props["defaultChecked"]
    props.delete("defaultValue")
    props.delete("defaultChecked")
    props.delete("checked")
    props["checked"] = checked if checked
    node = node.merge("props" => props)
    case name
    when "input" then props["value"] = value unless value.nil?
    when "textarea" then node = node.merge("props" => props.except("value"), "children" => value.nil? ? node["children"] : [ value.to_s ])
    when "select" then node = node.merge("props" => props.except("value"), "children" => select_option(node["children"], Array(value).map(&:to_s))) unless value.nil?
    end
    node
  end

  def select_option(children, values)
    Array(children).map do |child|
      next child unless child.is_a?(Hash)

      child = child.merge("children" => select_option(child["children"], values)) if child["c"] == "_optgroup"
      child["c"] == "_option" && values.include?((child.dig("props", "value") || "").to_s) ? child.merge("props" => child["props"].merge("selected" => true)) : child
    end
  end

  def render_children(children, roots)
    Array(children).each do |child|
      next render_node(child, roots) if child.is_a?(Hash)
      raise Error, "a child must be a String or a Hash, got #{child.class}" unless child.is_a?(String)

      icon = child.match(ICON)
      render Phlex::Shadcn::Icon.new(icon[1]) if icon
      plain(icon ? icon.post_match : child)
    end
  end

  def as_child_node(node)
    children = Array(node["children"])
    raise Error, "asChild needs exactly one child node (#{node['c']})" unless children.size == 1 && children.first.is_a?(Hash)

    children.first
  end

  def as_child_instance(node, roots)
    child = as_child_node(node)
    name = child.fetch("c")
    return ShadcnParity::RawElement.new(name.delete_prefix("_"), **raw_attrs(child["props"])) if name.match?(/\A_[a-z]/)

    resolve(name).klass.new(**component_props(child["props"]))
  end

  # React prop names to Ruby kwargs: className -> class, camelCase -> snake_case, data-*/aria-* untouched.
  def component_props(props)
    (props || {}).except("asChild").each_with_object({}) do |(key, value), out|
      key = key.sub(/\Aaria([A-Z])/) { "aria-#{Regexp.last_match(1).downcase}" }
      key = "class" if key == "className"
      value = css_properties(value) if key == "style" && value.is_a?(Hash)
      out[(key.match?(/[-:]/) ? key : key.underscore).to_sym] = value
    end
  end

  # React style object keys (minWidth, WebkitLineClamp, --custom) to CSS property names.
  def css_properties(style)
    style.to_h do |name, value|
      name = name.to_s
      name = name.start_with?("--") ? name : name.gsub(/([A-Z])/) { "-#{Regexp.last_match(1).downcase}" }.sub(/\Ams-/, "-ms-")
      [ name, value ]
    end
  end

  # Raw elements keep their HTML names (React DOM props via Base::DOM_ATTRIBUTES: className -> class, htmlFor -> for,
  # readOnly -> readonly, httpEquiv -> http-equiv); any other camelCase prop is lowercased.
  def raw_attrs(props)
    (props || {}).each_with_object({}) do |(key, value), out|
      key = Phlex::Shadcn::Base::DOM_ATTRIBUTES.fetch(key) { key.match?(/[a-z][A-Z]/) ? key.downcase : key }.to_s
      out[key.to_sym] = key == "style" && value.is_a?(Hash) ? css_properties(value) : value
    end
  end

  def resolve(name)
    raise Error, "malformed component name #{name.inspect}" unless name.to_s.match?(/\A_?[A-Z][A-Za-z0-9]*\z|\A_[a-z]/)

    namespace, bare, roots = name.start_with?("_") ? [ ShadcnParity, name.delete_prefix("_"), PARITY_ROOTS ] : [ Phlex::Shadcn, name, v2_roots ]
    # An exact root match wins over a same-named nested part of a longer root (Button vs InputGroup::Button).
    return Target.new(namespace.const_get(bare), nil, nil) if roots.include?(bare)

    ordered = ([ @primary ] & roots) + roots.sort_by { |r| -r.size }

    ordered.uniq.each do |root_name|
      root = namespace.const_get(root_name)
      return Target.new(root, nil, nil) if bare == root_name

      rest = bare.delete_prefix(root_name) if bare.start_with?(root_name)
      part_name = [ rest, bare ].compact.find { |n| root.const_defined?(n, false) && root.const_get(n, false).is_a?(Class) }
      return Target.new(root.const_get(part_name), root, part_name.underscore.to_sym) if part_name
    end
    raise Error, "unknown component #{name}"
  end

  # Root components: the top-level classes of the gem (registered by its loader, so no file access needed).
  def v2_roots
    @v2_roots ||= Phlex::Shadcn.constants(false).select do |name|
      part = Phlex::Shadcn.const_get(name)
      part.is_a?(Class) && part < Phlex::Shadcn::Base
    end.map(&:to_s)
  end
end
