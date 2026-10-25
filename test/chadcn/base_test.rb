# frozen_string_literal: true

require "chadcn/test_case"
require "tempfile"

class Chadcn::BaseTest < Chadcn::TestCase
  class Probe < Chadcn::Base
    public :merge_attrs, :normalize_option, :ids, :render_as_child, :validated_id
  end

  class Kid < Chadcn::Base
    def initialize(**attrs) = @attrs = attrs

    def view_template(&)
      attrs = merge_attrs({ class: "px-2", data: { slot: "kid" } }, @attrs)
      tag(:span, **attrs, &)
    end
  end

  class Slotter < Chadcn::Base
    def initialize(as_child:, **slot)
      (@child = as_child
       @slot = slot)
    end

    def view_template(&) = render_as_child(@child, **@slot, &)
  end

  class Table < Chadcn::Base
    def initialize(**attrs) = @attrs = attrs

    def view_template(&block)
      tag(:table, **@attrs) { yield self if block }
    end

    class Header < Chadcn::Base
      def initialize(**attrs) = @attrs = attrs
      def view_template(&) = tag(:thead, **@attrs, &)
    end

    class CheckboxItem < Chadcn::Base
      def initialize(**attrs) = @attrs = attrs
      def view_template(&) = tag(:td, **@attrs, &)
    end

    class Plain; end
  end

  class Row < Chadcn::Base
    def initialize(table:) = @table = table
    def view_template = @table.checkbox_item { "x" }
  end

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  test "generates a helper per nested Base part and none for plain classes" do
    assert_equal %i[checkbox_item header], (Table.instance_methods(false) - [ :view_template ]).sort
  end

  test "helper output equals the explicit render, with attrs and block forwarded" do
    helpers = render_view do
      render(Table.new(class: "t")) { |t| t.header(class: "h", data: { a: 1 }) { "Hi" } }
    end
    explicit = render_view do
      render(Table.new(class: "t")) { render(Table::Header.new(class: "h", data: { a: 1 })) { "Hi" } }
    end

    assert_equal explicit, helpers
    assert_includes helpers, '<thead class="h" data-a="1">Hi</thead>'
  end

  test "helpers work when the yielded root is passed to another component" do
    html = render_view { render(Table.new) { |t| render Row.new(table: t) } }

    assert_includes html, "<td>x</td>"
  end

  test "a name that overrides a Ruby or Phlex API method raises" do
    assert_raises(ArgumentError) { Class.new(Chadcn::Base) { const_set(:Render, Class.new(Chadcn::Base)) } }
    assert_raises(ArgumentError) { Class.new(Chadcn::Base) { const_set(:Context, Class.new(Chadcn::Base)) } }
  end

  test "an HTML element name is allowed" do
    klass = Class.new(Chadcn::Base) { const_set(:Title, Class.new(Chadcn::Base)) }

    assert klass.method_defined?(:title)
  end

  test "cn resolves conflicts" do
    assert_equal "rounded-full", Probe.new.send(:cn, "rounded-md", "rounded-full")
  end

  test "normalize_option" do
    p = Probe.new

    assert_equal "icon-sm", p.normalize_option(:icon_sm)
    assert_equal "icon-sm", p.normalize_option("icon-sm")
    assert_nil p.normalize_option(nil)
  end

  test "ids" do
    assert_equal "d-title", Probe.new.ids("d")[:title]
    assert_equal "d-aria-label", Probe.new.ids("d")[:aria_label]
  end

  test "validated_id answers nil when the root generates its id, else the id as a String" do
    probe = Probe.new

    assert_nil probe.validated_id(nil)
    assert_nil probe.validated_id(false)
    assert_equal "faq", probe.validated_id(:faq)
    assert_equal "faq", probe.validated_id("faq")
    assert_equal "7", probe.validated_id(7)
  end

  test "validated_id raises for what is not one id token" do
    probe = Probe.new
    [ "", "a b", "a\tb", 'a"b', "a\\b" ].each do |id|
      error = assert_raises(ArgumentError) { probe.validated_id(id) }

      assert_includes error.message, "id:"
    end
  end

  test "merge_attrs deep-merges data/aria, caller wins, class via cn, actions concatenated" do
    out = Probe.new.merge_attrs(
      { class: "rounded-md p-2", data: { slot: "a", action: "click->x#y" }, aria: { hidden: true } },
      { class: "rounded-full", "data-slot": "b", data: { action: "focus->x#z" }, "aria-label": "L" }
    )

    assert_equal "p-2 rounded-full", out[:class]
    assert_equal({ slot: "b", action: "click->x#y focus->x#z" }, out[:data])
    assert_equal({ hidden: "true", label: "L" }, out[:aria])
  end

  test "render_as_child: child wins, plain class join, action child first, style merged" do
    html = render_view do
      render Slotter.new(
        as_child: Kid.new(class: "rounded-full", data: { slot: "child", action: "click->c#a" }, style: "color: red", id: "child"),
        class: "rounded-md", data: { slot: "slot", state: "open", action: "click->s#b" }, style: "margin: 0", id: "slot"
      ) { "t" }
    end
    doc = Nokogiri::HTML.fragment(html).at("span")

    assert_equal "child", doc["id"]
    assert_equal "child", doc["data-slot"]
    assert_equal "open", doc["data-state"]
    assert_equal "click->c#a click->s#b", doc["data-action"]
    assert_equal "margin: 0; color: red", doc["style"]
    assert_includes doc["class"].split, "rounded-md"
    assert_includes doc["class"].split, "rounded-full"
  end

  test "render_as_child with only slot props or only child props" do
    only_slot = render_view { render(Slotter.new(as_child: :a, class: "x", href: "/")) { "t" } }

    assert_equal '<a class="x" href="/">t</a>', only_slot
    only_child = render_view { render(Slotter.new(as_child: Kid.new(id: "k"))) { "t" } }

    assert_includes only_child, 'id="k"'
  end

  test "render_as_child unions controllers and concatenates describedby" do
    html = render_view do
      render Slotter.new(as_child: Kid.new(data: { controller: "b a" }, aria: { describedby: "c s" }),
                         data: { controller: "a z" }, aria: { describedby: "s d" })
    end
    span = Nokogiri::HTML.fragment(html).at("span")

    assert_equal "a z b", span["data-controller"]
    assert_equal "c s d", span["aria-describedby"]
  end

  test "React DOM props written in snake_case or camelCase become HTML attribute names" do
    out = Probe.new.merge_attrs({}, { tab_index: 0, form_no_validate: true, read_only: true, max_length: 3, "autoComplete" => "off",
                                      spell_check: false, http_equiv: "refresh", html_for: "x", class_name: "a", stroke_width: 2 })

    assert_equal({ tabindex: 0, formnovalidate: true, readonly: true, maxlength: 3, autocomplete: "off", spellcheck: false,
                   "http-equiv": "refresh", for: "x", class: "a", stroke_width: 2 }, out)
  end

  test "DOM prop names render as valid attributes" do
    html = render_view { tag(:input, **Probe.new.merge_attrs({}, { tab_index: -1, read_only: true, auto_focus: true })) }

    assert_equal '<input tabindex="-1" readonly autofocus>', html
  end

  test "boolean aria/data values are strings like React, other booleans stay booleans" do
    out = Probe.new.merge_attrs({ aria: { expanded: false } },
                                { "aria-checked": true, "data-active": false, data: { open: true }, disabled: true, required: false })

    assert_equal({ expanded: "false", checked: "true" }, out[:aria])
    assert_equal({ active: "false", open: "true" }, out[:data])
    assert out[:disabled]
    refute out[:required]
  end

  test "render_as_child stringifies boolean aria and maps DOM props" do
    html = render_view { render(Slotter.new(as_child: :button, aria: { pressed: true }, tab_index: 0)) { "t" } }

    assert_equal '<button aria-pressed="true" tabindex="0">t</button>', html
  end

  test "nil data and aria are treated as empty" do
    html = render_view { render(Slotter.new(as_child: :button, data: nil, aria: nil)) { "t" } }

    assert_equal "<button>t</button>", html
  end

  class AppTable < Table; end

  test "helpers keep working on a subclass of a root" do
    html = render_view { render(AppTable.new) { |t| t.header { "Hi" } } }

    assert_includes html, "<thead>Hi</thead>"
  end

  # Parts that live in their own file are registered lazily by the loader; the hook must still define their helper at
  # registration time, and a real NameError raised by a part's file is deferred to the first real access (or eager load),
  # never swallowed.
  module LazyRoots; end

  def lazy_root(name, source)
    root = Class.new(Chadcn::Base)
    LazyRoots.const_set(name, root)
    file = Tempfile.new([ name.to_s, ".rb" ])
    file.write(source.call(root))
    file.flush
    [ root, file ]
  end

  test "a lazily loaded part gets its helper when it is registered" do
    root, file = lazy_root(:Good, ->(r) { "class #{r.name}::FooBar < Chadcn::Base; end" })
    root.autoload(:FooBar, file.path)

    assert_respond_to root.new, :foo_bar
  ensure
    file&.close!
  end

  test "a NameError raised by a part file is deferred to the first real access, not lost" do
    root, file = lazy_root(:Bad, ->(r) { "class #{r.name}::Broken < Chadcn::Base\n  NotDefinedAnywhere\nend" })
    root.autoload(:Broken, file.path)

    error = assert_raises(NameError) { root.const_get(:Broken) }
    assert_match(/NotDefinedAnywhere/, error.message)
  ensure
    file&.close!
  end
end
