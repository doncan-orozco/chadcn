# frozen_string_literal: true

using Chadcn::Values::Refinements

# Renders a JSON `tree` with the components of the gem. The tree is read with these rules (the React side of the parity harness,
# dev/react-shadcn-catalog/src/parity/Harness.tsx, reads it with the same ones):
#
# - a node is `{ "c" => name, "props" => {...}, "children" => [...] }`
# - `c` "_a", "_div"... (underscore + lowercase): a raw HTML element; props become attributes
# - `c` "DialogTrigger": `Chadcn::Dialog::Trigger` (root prefix stripped); "Button" is `Chadcn::Button`
# - props: React names are mapped to Ruby ones (`className` is `class`, camelCase is snake_case, `data-*` and `aria-*` stay)
# - children: strings are text; a string starting with `<icon:name>` renders that icon (the rest is text)
# - `asChild: true`: the single child node becomes the `as_child:` instance and its children the content
# - a child `{ "c": "_Each", "children": [template...] }` turns the parent's block into one that takes the yielded argument
#   (Combobox::List item, Combobox::Value values): the template is rendered once per element of an Array argument, or once;
#   "$item" / "$item.<path>" in a string prop or text child become that element (not inside a nested `_Each`)
# - a string prop "$ref:<css selector>" is passed as the selector string (React side: a lazy ref)
# - a string anywhere inside a prop value "$date:YYYY-MM-DD" is passed as the ISO string "YYYY-MM-DD" (React side: a local Date);
#   "$locale:es" is passed as the BCP 47 tag "es" (React side: the react-day-picker locale)
# - the recharts nodes of a chart scenario (`_BarChart`, `_Bar`, `_XAxis`, ...; underscore + capital) resolve to `Chadcn::Chart::*`, with
#   `ChartTooltipContent` / `ChartLegendContent` as a `content:` prop (+ `contentProps`) or as a node of their own, and named formatters
#   (`{ "formatter": "slice", "args": [0, 3] }`); see {Chadcn::Catalog::ChartScope}
#
# With `dx: "helpers"` nested parts render through the YIELDED root (`root.header { ... }`) instead of `Root::Header.new`.
#
# Raises {Error} for a malformed or unknown node. Loaded on demand (Zeitwerk), so a host that never renders a catalog does not pay for it.
#
# @example Render the example of one component
#   render Chadcn::Catalog::TreeRenderer.new(tree: Chadcn::Catalog.find("card").tree, component: "card")
class Chadcn::Catalog::TreeRenderer < Phlex::HTML
  # A malformed node, or a component name the gem does not know.
  class Error < StandardError; end

  prepend Chadcn::Catalog::ChartScope

  ICON = /\A<icon:([\w-]+)>/
  REF = /\A\$ref:/
  DATE = /\A\$date:(\d{4}-\d{2}-\d{2})\z/
  LOCALE = /\A\$locale:(.+)\z/
  Target = Struct.new(:klass, :root, :helper)
  private_constant :ICON, :REF, :DATE, :LOCALE, :Target

  # @param tree [Hash] the root node of the tree
  # @param component [String, Symbol, nil] the component the tree belongs to (`"button-group"`); a part name that exists on several
  #   roots resolves against this one first (`InputGroup`'s `Button` part vs `Button`)
  # @param dx [String, nil] `"helpers"` to render nested parts through the yielded root
  def initialize(tree:, component: nil, dx: nil) # rubocop:disable Naming/MethodParameterName -- dx is the harness and docs vocabulary
    @tree = tree
    @primary = component.to_s.delete_prefix("_").split(/[-_]/).map { |word| word.sub(/\A./, &:upcase) }.join.then { |name| name unless name.empty? }
    @dx = dx.to_s == "helpers"
    super()
  end

  # @return [void]
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
    return render_each_node(node, target, props, content, roots) if each_node?(content)

    if @dx && target.root && roots[target.root]
      roots[target.root].public_send(target.helper, **props) { render_children(content, roots) }
    elsif @dx && target.root.nil?
      render(target.klass.new(**props)) { |root| render_children(content, root.is_a?(target.klass) ? roots.merge(target.klass => root) : roots) }
    else
      render(target.klass.new(**props)) { render_children(content, roots) }
    end
  end

  def each_node?(children)
    Array(children).any? { |child| child.is_a?(Hash) && child["c"] == "_Each" }
  end

  # The parent's block receives the argument its component yields; `_Each` children are expanded against it.
  def render_each_node(_node, target, props, content, roots)
    block = proc do |arg = nil|
      expanded = Array(content).flat_map { |child| child.is_a?(Hash) && child["c"] == "_Each" ? expand_each(child, arg) : [ child ] }
      render_children(expanded, roots)
    end
    if @dx && target.root && roots[target.root]
      roots[target.root].public_send(target.helper, **props, &block)
    else
      render(target.klass.new(**props), &block)
    end
  end

  def expand_each(each, arg)
    (arg.is_a?(Array) ? arg : [ arg ]).flat_map { |element| Array(each["children"]).map { |template| substitute(template, element) } }
  end

  # "$item" / "$item.a.b" -> the element (or its property); a nested `_Each` keeps its own children for its own argument.
  def substitute(value, item)
    case value
    when String
      return item if value == "$item"
      return value unless value.start_with?("$item.")

      value.delete_prefix("$item.").split(".").reduce(item) { |acc, part| acc.is_a?(Hash) ? acc[part] : nil }
    when Array then value.map { |v| substitute(v, item) }
    when Hash
      return value.merge("props" => substitute(value["props"] || {}, item)) if value["c"] == "_Each"
      return value.transform_values { |v| substitute(v, item) } unless value.key?("c")

      value.merge("props" => substitute(value["props"] || {}, item), "children" => Array(value["children"]).map { |child| substitute(child, item) })
    else value
    end
  end

  def render_raw(node, roots)
    name = node["c"].delete_prefix("_")
    node = raw_value_semantics(name, node)
    render(Chadcn::Catalog::RawElement.new(name, **raw_attrs(node["props"]))) do
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
    when "select" then unless value.nil?
                         node = node.merge("props" => props.except("value"),
                                           "children" => select_option(node["children"],
                                                                       Array(value).map(&:to_s)))
                       end
    end
    node
  end

  def select_option(children, values)
    Array(children).map do |child|
      next child unless child.is_a?(Hash)

      child = child.merge("children" => select_option(child["children"], values)) if child["c"] == "_optgroup"
      if child["c"] == "_option" && values.include?((child.dig("props",
                                                               "value") || "").to_s)
        child.merge("props" => child["props"].merge("selected" => true))
      else
        child
      end
    end
  end

  def render_children(children, roots)
    Array(children).each do |child|
      next render_node(child, roots) if child.is_a?(Hash)
      raise Error, "a child must be a String or a Hash, got #{child.class}" unless child.is_a?(String)

      icon = child.match(ICON)
      render Chadcn::Icon.new(icon[1]) if icon
      plain(icon ? icon.post_match : child)
    end
  end

  def as_child_node(node)
    children = Array(node["children"])
    raise Error, "asChild needs exactly one child node (#{node['c']})" unless children.size == 1 && children.first.is_a?(Hash)

    children.first
  end

  def as_child_instance(node, _roots)
    child = as_child_node(node)
    name = child.fetch("c")
    return Chadcn::Catalog::RawElement.new(name.delete_prefix("_"), **raw_attrs(child["props"])) if name.match?(/\A_[a-z]/)

    resolve(name).klass.new(**component_props(child["props"]))
  end

  # React prop names to Ruby kwargs: className -> class, camelCase -> snake_case, data-*/aria-* untouched.
  def component_props(props)
    (props || {}).except("asChild").each_with_object({}) do |(key, value), out|
      key = key.sub(/\Aaria([A-Z])/) { "aria-#{Regexp.last_match(1).downcase}" }
      key = "class" if key == "className"
      value = css_properties(value) if key == "style" && value.is_a?(Hash)
      value = value.sub(REF, "") if value.is_a?(String) && value.match?(REF)
      value = plain_values(value)
      out[(key.match?(/[-:]/) ? key : key.snake_case).to_sym] = value
    end
  end

  # "$date:2026-03-15" -> "2026-03-15", "$locale:es" -> "es" (exact shapes, like Harness.tsx;
  # anything else stays verbatim), at any depth (nested hashes keep their React key names).
  def plain_values(value)
    case value
    when String then (value[DATE, 1] || value[LOCALE, 1]) || value
    when Array then value.map { |v| plain_values(v) }
    when Hash then value.key?("c") ? value : value.transform_values { |v| plain_values(v) }
    else value
    end
  end

  # React style object keys (minWidth, WebkitLineClamp, --custom) to CSS property names.
  def css_properties(style)
    style.to_h do |name, value|
      name = name.to_s
      name = name.gsub(/([A-Z])/) { "-#{Regexp.last_match(1).downcase}" }.sub(/\Ams-/, "-ms-") unless name.start_with?("--")
      [ name, value ]
    end
  end

  # Raw elements keep their HTML names (React DOM props via Base::DOM_ATTRIBUTES: className -> class, htmlFor -> for,
  # readOnly -> readonly, httpEquiv -> http-equiv); any other camelCase prop is lowercased.
  def raw_attrs(props)
    (props || {}).each_with_object({}) do |(key, value), out|
      key = Chadcn::Base::DOM_ATTRIBUTES.fetch(key) { key.match?(/[a-z][A-Z]/) ? key.downcase : key }.to_s
      out[key.to_sym] = key == "style" && value.is_a?(Hash) ? css_properties(value) : value
    end
  end

  def resolve(name)
    raise Error, "malformed component name #{name.inspect}" unless name.to_s.match?(/\A_?[A-Z][A-Za-z0-9]*\z|\A_[a-z]/)

    namespace, bare, roots = name.start_with?("_") ? harness_scope(name.delete_prefix("_")) : [ Chadcn, name, v2_roots ]
    # An exact root match wins over a same-named nested part of a longer root (Button vs InputGroup::Button).
    return Target.new(namespace.const_get(bare), nil, nil) if roots.include?(bare)

    ordered = ([ @primary ] & roots) + roots.sort_by { |r| -r.size }

    ordered.uniq.each do |root_name|
      root = namespace.const_get(root_name)
      return Target.new(root, nil, nil) if bare == root_name

      rest = bare.delete_prefix(root_name) if bare.start_with?(root_name)
      part_name = [ rest, bare ].compact.find { |n| root.const_defined?(n, false) && root.const_get(n, false).is_a?(Class) }
      return Target.new(root.const_get(part_name), root, part_name.snake_case.to_sym) if part_name
    end
    raise Error, "unknown component #{name}"
  end

  # A harness stub (`c` "_Probe": underscore + capital) belongs to a test harness, not to the gem, except the recharts nodes of
  # {Chadcn::Catalog::ChartScope}; a subclass returns [namespace, bare name, root names] for the stubs it knows.
  def harness_scope(bare) = raise(Error, "unknown component _#{bare}")

  # Root components: the top-level classes of the gem (registered by its loader, so no file access needed).
  def v2_roots
    @v2_roots ||= Chadcn.constants(false).select do |name|
      part = Chadcn.const_get(name)
      part.is_a?(Class) && part < Chadcn::Base
    end.map(&:to_s)
  end
end
