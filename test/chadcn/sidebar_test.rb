# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SidebarTest < Chadcn::TestCase
  Sidebar = Chadcn::Sidebar

  # Sidebar helper name => the part class it renders (each helper must exist on Sidebar and render that part)
  HELPERS = {
    content: Sidebar::Content, footer: Sidebar::Footer, group: Sidebar::Group, group_action: Sidebar::GroupAction,
    group_content: Sidebar::GroupContent, group_label: Sidebar::GroupLabel, header: Sidebar::Header, input: Sidebar::Input,
    inset: Sidebar::Inset, menu: Sidebar::Menu, menu_action: Sidebar::MenuAction, menu_badge: Sidebar::MenuBadge,
    menu_button: Sidebar::MenuButton, menu_item: Sidebar::MenuItem, menu_skeleton: Sidebar::MenuSkeleton,
    menu_sub: Sidebar::MenuSub, menu_sub_button: Sidebar::MenuSubButton, menu_sub_item: Sidebar::MenuSubItem,
    provider: Sidebar::Provider, rail: Sidebar::Rail, separator: Sidebar::Separator, trigger: Sidebar::Trigger
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def provider(options = {}, &block)
    block ||= proc { }
    render_view { render(Sidebar::Provider.new(**options)) { instance_exec(&block) } }
  end

  test "provider is the controller host with the wrapper variables" do
    wrapper = fragment(provider(class: "extra", style: { "--sidebar-width" => "20rem" }, id: "x")).at_css("[data-slot=sidebar-wrapper]")

    assert_equal "chadcn--sidebar", wrapper["data-controller"]
    assert_equal "true", wrapper["data-chadcn--sidebar-open-value"]
    assert_equal "false", wrapper["data-chadcn--sidebar-controlled-value"]
    assert_includes wrapper["class"].split, "extra"
    assert_equal "x", wrapper["id"]
    assert_equal "--sidebar-width: 20rem; --sidebar-width-icon: 3rem;", wrapper["style"]
    string = fragment(provider(style: "--sidebar-width: 5rem;")).at_css("[data-slot=sidebar-wrapper]")

    assert_equal "--sidebar-width: 16rem; --sidebar-width-icon: 3rem; --sidebar-width: 5rem;", string["style"]
    assert_nil wrapper["data-state"]
  end

  test "desktop sidebar carries the state attributes, the container takes class and attrs, a template holds the mobile sheet" do
    html = provider(default_open: false) do
      render(Sidebar.new(side: :right, variant: :floating, collapsible: :icon, class: "w-9",
                         id: "side")) do
        "block"
      end
    end
    doc = fragment(html)
    outer = doc.at_css("[data-slot=sidebar]")

    assert_equal(%w[collapsed icon floating right], %w[state collapsible variant side].map { |name| outer["data-#{name}"] })
    assert_equal "side", outer.at_css("[data-slot=sidebar-container]")["id"]
    assert_nil outer["id"]
    assert_includes outer.at_css("[data-slot=sidebar-container]")["class"].split, "w-9"
    assert_equal "block", outer.at_css("[data-slot=sidebar-inner]").text
    template = doc.at_css("template[data-chadcn--sidebar-target=mobile]")

    assert template
    assert_nil template["data-slot"]
    assert template.at_css("template [data-slot=sidebar][data-mobile=true]")
  end

  test "expanded sidebar has an empty data-collapsible and collapsible none renders a single div" do
    assert_equal "", fragment(provider { render(Sidebar.new) }).at_css("[data-slot=sidebar]")["data-collapsible"]
    none = fragment(provider { render(Sidebar.new(collapsible: "none", class: "x")) { "b" } })

    assert_equal 1, none.css("[data-slot=sidebar]").size
    assert_nil none.at_css("[data-slot=sidebar]")["data-state"]
    assert_nil none.at_css("template")
  end

  test "unknown options raise and sidebar parts that use the context need a provider" do
    assert_raises(ArgumentError) { Sidebar.new(side: "top") }
    assert_raises(ArgumentError) { provider { render(Sidebar.new(variant: "x")) } }
    error = assert_raises(ArgumentError) { render_view { render(Sidebar::Trigger.new) } }

    assert_equal "useSidebar must be used within a SidebarProvider.", error.message
    assert_raises(ArgumentError) { render_view { render(Sidebar.new) } }
    assert_raises(ArgumentError) { render_view { render(Sidebar::Rail.new) } }
    assert_raises(ArgumentError) { render_view { render(Sidebar::MenuButton.new) } }
    assert fragment(render_view { render(Sidebar::MenuSubButton.new) { "x" } }).at_css("a[data-slot=sidebar-menu-sub-button]")
  end

  test "trigger merges class, variant and attrs; the toggle runs after the caller actions" do
    html = provider { render(Sidebar::Trigger.new(class: "ml-1", size: "icon-sm", data: { action: "click->x#y" }, aria: { label: "T" })) }
    button = fragment(html).at_css("[data-slot=sidebar-trigger]")

    assert_equal "ghost", button["data-variant"]
    assert_equal "icon-sm", button["data-size"]
    assert_equal "trigger", button["data-sidebar"]
    assert_equal "click->x#y click->chadcn--sidebar#toggle", button["data-action"]
    assert_includes button["class"].split, "size-7"
    assert_includes button["class"].split, "ml-1"
    assert_equal "Toggle Sidebar", button.at_css(".sr-only").text
  end

  test "trigger label can be overridden" do
    button = fragment(provider { render(Sidebar::Trigger.new(label: "Alternar barra lateral")) }).at_css("[data-slot=sidebar-trigger]")

    assert_equal "Alternar barra lateral", button.at_css(".sr-only").text
  end

  test "mobile sheet title and description default to the React strings and can be overridden" do
    sheet = ->(**props) { fragment(provider { render(Sidebar.new(**props)) }).at_css("template template") }
    default = sheet.call
    custom = sheet.call(mobile_title: "Barra lateral", mobile_description: "Muestra la barra lateral móvil.")

    assert_equal "Sidebar", default.at_css("[data-slot=sheet-title]").text
    assert_equal "Displays the mobile sidebar.", default.at_css("[data-slot=sheet-description]").text
    assert_equal "Barra lateral", custom.at_css("[data-slot=sheet-title]").text
    assert_equal "Muestra la barra lateral móvil.", custom.at_css("[data-slot=sheet-description]").text
  end

  test "rail defaults can be overridden" do
    rail = fragment(provider { render(Sidebar::Rail.new(title: "Other")) }).at_css("[data-slot=sidebar-rail]")

    assert_equal "-1", rail["tabindex"]
    assert_equal "Toggle Sidebar", rail["aria-label"]
    assert_equal "Other", rail["title"]
  end

  test "menu button renders variants, sizes, active state and as_child" do
    button = fragment(provider do
      render(Sidebar::MenuButton.new(variant: :outline, size: :lg, is_active: true, class: "p-4")) do
        "x"
      end
    end).at_css("button")

    assert_equal "true", button["data-active"]
    assert_equal "lg", button["data-size"]
    assert_includes button["class"].split, "h-12"
    assert_includes button["class"].split, "p-4"
    assert_not_includes button["class"].split, "p-2"
    link = fragment(provider do
      render(Sidebar::MenuButton.new(as_child: :a, href: "#")) do
        "x"
      end
    end).at_css("a[data-slot=sidebar-menu-button]")

    assert_equal "false", link["data-active"]
    assert_raises(ArgumentError) { Sidebar::MenuButton.new(size: "huge") }
    %w[h-7 text-xs].each { |token| assert_includes Sidebar::MenuButton.variants(size: "sm").split, token }
  end

  test "menu button tooltip becomes a tooltip trigger and a content hidden while expanded" do
    html = provider { render(Sidebar::MenuButton.new(tooltip: "Home")) { "x" } }
    doc = fragment(html)
    button = doc.at_css("button[data-slot=sidebar-menu-button]")

    assert_equal "closed", button["data-state"]
    assert_includes button["data-controller"], "chadcn--tooltip"
    content = doc.at_css("template div[data-slot=tooltip-content]")

    assert content.key?("hidden")
    assert_not_empty content["data-chadcn--sidebar-tooltip"].to_s
    assert_equal "right", JSON.parse(doc.at_css("template[data-options]")["data-options"])["side"]
    assert_equal "Home", content.text
    collapsed = fragment(provider(default_open: false) { render(Sidebar::MenuButton.new(tooltip: { children: "H", hidden: false })) })

    assert_not collapsed.at_css("template div[data-slot=tooltip-content]").key?("hidden")
    assert_not collapsed.at_css("template div[data-slot=tooltip-content]").key?("data-chadcn--sidebar-tooltip")
  end

  test "menu skeleton draws its width between 50 and 89 percent" do
    skeleton = fragment(provider { render(Sidebar::MenuSkeleton.new(show_icon: true)) })

    assert skeleton.at_css("[data-sidebar=menu-skeleton-icon]")
    assert_match(/--skeleton-width: (5\d|[6-8]\d)%/, skeleton.at_css("[data-sidebar=menu-skeleton-text]")["style"])
  end

  test "menu skeleton width defaults to a value within 50..89" do
    widths = Array.new(8) { fragment(provider { render(Sidebar::MenuSkeleton.new) }).at_css("[data-sidebar=menu-skeleton-text]")["style"][/--skeleton-width: (\d+)%/, 1].to_i }

    assert(widths.all? { |w| (50..89).cover?(w) })
  end

  test "menu skeleton width can be pinned and the pin is always restored" do
    # 42 is outside the random 50..89 range, so seeing it proves the pin and seeing anything else proves the restore.
    pinned = Sidebar::MenuSkeleton.with_pinned_width(42) { provider { render(Sidebar::MenuSkeleton.new) } }
    width_of = ->(html) { fragment(html).at_css("[data-sidebar=menu-skeleton-text]")["style"][/--skeleton-width: (\d+)%/, 1].to_i }

    assert_equal 42, width_of.call(pinned)
    assert_includes 50..89, width_of.call(provider { render(Sidebar::MenuSkeleton.new) })

    assert_raises(RuntimeError) { Sidebar::MenuSkeleton.with_pinned_width(42) { raise "boom" } }
    assert_includes 50..89, width_of.call(provider { render(Sidebar::MenuSkeleton.new) })
  end

  test "every DX helper renders the same HTML as the explicit class" do
    normalize = ->(html) { html.gsub(/--skeleton-width: \d+%/, "w").gsub(/(sheet|tooltip-provider|tooltip|sidebar)-\d+/, '\1') }
    HELPERS.each do |name, klass|
      explicit = provider { render(Sidebar.new) { render(klass.new) { "x" } } }
      helper = provider { render(Sidebar.new) { |sidebar| sidebar.public_send(name) { "x" } } }

      assert_equal normalize.call(explicit), normalize.call(helper), name.to_s
    end
    assert_respond_to Sidebar.new, :provider
  end

  test "provider open is controlled, default_open is not" do
    controlled = fragment(provider(open: false)).at_css("[data-slot=sidebar-wrapper]")

    assert_equal "false", controlled["data-chadcn--sidebar-open-value"]
    assert_equal "true", controlled["data-chadcn--sidebar-controlled-value"]
    assert_equal "false", fragment(provider(default_open: false)).at_css("[data-slot=sidebar-wrapper]")["data-chadcn--sidebar-controlled-value"]
    assert_equal "collapsed", fragment(provider(open: false) { render(Sidebar.new) }).at_css("[data-slot=sidebar]")["data-state"]
  end

  test "use_sidebar returns the state of the nearest provider" do
    captured = nil
    probe = Class.new(Chadcn::Base) do
      define_method(:view_template) { captured = Sidebar.use_sidebar(self) }
    end
    provider(default_open: false) { render probe.new }

    assert_equal "collapsed", captured.state
    assert_not captured.open
    assert_not captured.is_mobile
    assert_match(/\Asidebar-\d+\z/, captured.id)
  end

  test "simple parts render their tag and merge class, data and aria from the caller" do
    tags = { content: "div", footer: "div", group: "div", group_content: "div", header: "div", menu: "ul", menu_item: "li",
             menu_sub: "ul", menu_sub_item: "li", menu_badge: "div", inset: "main" }
    tags.each do |name, tag|
      html = provider { render(Sidebar.new) { |sidebar| sidebar.public_send(name, class: "zz", id: "p", data: { testid: "t" }, aria: { label: "L" }) { "x" } } }
      element = fragment(html).at_css("#{tag}#p")

      assert_includes element["class"].split, "zz", name.to_s
      assert_equal "t", element["data-testid"], name.to_s
      assert_equal "L", element["aria-label"], name.to_s
      assert_equal "x", element.text, name.to_s
    end
  end

  test "as_child parts render the child element with the part attributes" do
    { group_action: %w[button sidebar-group-action], group_label: %w[div sidebar-group-label],
      menu_action: %w[button sidebar-menu-action], menu_sub_button: %w[a sidebar-menu-sub-button] }.each do |name, (default_tag, slot)|
      default = fragment(provider { render(Sidebar.new) { |sidebar| sidebar.public_send(name) { "x" } } }).at_css("[data-slot=#{slot}]")
      html = provider { render(Sidebar.new) { |sidebar| sidebar.public_send(name, as_child: :section, class: "zz") { "x" } } }
      child = fragment(html).at_css("[data-slot=#{slot}]")

      assert_equal default_tag, default.name, name.to_s
      assert_equal "section", child.name, name.to_s
      assert_includes child["class"].split, "zz", name.to_s
    end
  end

  test "group action and menu action carry no type attribute" do
    html = provider do
      render(Sidebar.new) do |sidebar|
        sidebar.group_action
        sidebar.menu_action
      end
    end

    assert_nil fragment(html).at_css("[data-slot=sidebar-group-action]")["type"]
    assert_nil fragment(html).at_css("[data-slot=sidebar-menu-action]")["type"]
  end

  test "menu action show_on_hover adds the reveal classes only on request" do
    shown = fragment(provider { render(Sidebar::MenuAction.new(show_on_hover: true)) }).at_css("[data-slot=sidebar-menu-action]")
    plain = fragment(provider { render(Sidebar::MenuAction.new) }).at_css("[data-slot=sidebar-menu-action]")

    assert_includes shown["class"].split, "md:opacity-0"
    assert_not_includes plain["class"].split, "md:opacity-0"
  end

  test "menu sub button size, active state and default tag" do
    small = fragment(provider { render(Sidebar::MenuSubButton.new(size: :sm, is_active: true, href: "/x")) }).at_css("a")

    assert_equal "sm", small["data-size"]
    assert_equal "true", small["data-active"]
    assert_equal "/x", small["href"]
    assert_includes small["class"].split, "text-xs"

    default = fragment(provider { render(Sidebar::MenuSubButton.new) }).at_css("a")

    assert_equal "md", default["data-size"]
    assert_equal "false", default["data-active"]
    assert_raises(ArgumentError) { Sidebar::MenuSubButton.new(size: "xl") }
  end

  test "menu button variants class helper validates its options" do
    assert_includes Sidebar::MenuButton.variants(variant: "outline", size: :lg).split, "shadow-[0_0_0_1px_var(--sidebar-border)]"
    assert_raises(KeyError) { Sidebar::MenuButton.variants(variant: "nope") }
    assert_raises(ArgumentError) { Sidebar::MenuButton.new(variant: "nope") }
    assert_includes fragment(provider { render(Sidebar::MenuButton.new(variant: "outline")) }).at_css("button")["class"].split, "bg-background"
  end

  test "input renders the shared input with the sidebar data and type" do
    input = fragment(provider { render(Sidebar::Input.new(type: "search", class: "zz", placeholder: "Find", data: { testid: "t" })) }).at_css("input")

    assert_equal "search", input["type"]
    assert_equal "Find", input["placeholder"]
    assert_equal "sidebar-input", input["data-slot"]
    assert_equal "input", input["data-sidebar"]
    assert_equal "t", input["data-testid"]
    assert_includes input["class"].split, "zz"
    assert_includes input["class"].split, "h-8"
  end

  test "separator forwards orientation, decorative and as_child to the shared separator" do
    default = fragment(provider { render(Sidebar::Separator.new(class: "zz")) }).at_css("[data-sidebar=separator]")

    assert_equal "sidebar-separator", default["data-slot"]
    assert_equal "horizontal", default["data-orientation"]
    assert_includes default["class"].split, "zz"
    assert_includes default["class"].split, "mx-2"

    vertical = fragment(provider { render(Sidebar::Separator.new(orientation: "vertical", decorative: false)) }).at_css("[data-sidebar=separator]")

    assert_equal "vertical", vertical["data-orientation"]
    assert_equal "separator", vertical["role"]
    assert_equal "hr", fragment(provider { render(Sidebar::Separator.new(as_child: :hr)) }).at_css("[data-sidebar=separator]").name
  end

  test "menu skeleton without an icon renders only the text bar and takes caller attrs" do
    skeleton = fragment(provider { render(Sidebar::MenuSkeleton.new(class: "zz", id: "sk")) })

    assert_nil skeleton.at_css("[data-sidebar=menu-skeleton-icon]")
    assert_includes skeleton.at_css("#sk")["class"].split, "zz"
    assert_equal 60, Sidebar::MenuSkeleton.with_pinned_width(60) { Sidebar::MenuSkeleton.width_percent }
  end

  test "trigger accepts a custom variant and rejects as_child" do
    button = fragment(provider { render(Sidebar::Trigger.new(variant: "outline")) }).at_css("[data-slot=sidebar-trigger]")

    assert_equal "outline", button["data-variant"]
    assert_raises(ArgumentError) { Sidebar::Trigger.new(as_child: true) }
  end

  test "sidebar sides and variants reach the container classes" do
    left = fragment(provider { render(Sidebar.new) }).at_css("[data-slot=sidebar-container]")
    right = fragment(provider { render(Sidebar.new(side: :right, variant: :inset)) }).at_css("[data-slot=sidebar-container]")

    assert_includes left["class"].split, "left-0"
    assert_includes right["class"].split, "right-0"
    assert_includes right["class"].split, "p-2"
    assert_includes Sidebar::SIDES, "left"
  end

  test "id stays on the wrapper and names the sidebar for its controller and tooltips" do
    doc = fragment(provider(id: "app-sidebar") do
      render(Sidebar.new) { |sidebar| sidebar.menu_button(tooltip: "Home") { "Home" } }
    end)

    assert_equal "app-sidebar", doc.at_css("[data-slot=sidebar-wrapper]")["id"]
    assert_equal "app-sidebar", doc.at_css("[data-slot=sidebar-wrapper]")["data-chadcn--sidebar-id-value"]
    assert_equal "app-sidebar", doc.at_css("template div[data-slot=tooltip-content]")["data-chadcn--sidebar-tooltip"]
  end
end
