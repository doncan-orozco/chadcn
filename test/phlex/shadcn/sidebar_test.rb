# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SidebarTest < Phlex::Shadcn::TestCase
  Sidebar = Phlex::Shadcn::Sidebar

  # helper => [part class, needs a Menu/MenuItem parent in the markup (none: plain render is enough)]
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

    assert_equal "shadcn--sidebar", wrapper["data-controller"]
    assert_equal "true", wrapper["data-shadcn--sidebar-open-value"]
    assert_equal "false", wrapper["data-shadcn--sidebar-controlled-value"]
    assert_includes wrapper["class"], "extra"
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
    assert_includes outer.at_css("[data-slot=sidebar-container]")["class"], "w-9"
    assert_equal "block", outer.at_css("[data-slot=sidebar-inner]").text
    template = doc.at_css("template[data-shadcn--sidebar-target=mobile]")

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
    assert_equal "click->x#y click->shadcn--sidebar#toggle", button["data-action"]
    assert_includes button["class"], "size-7"
    assert_includes button["class"], "ml-1"
    assert_equal "Toggle Sidebar", button.at_css(".sr-only").text
    assert_raises(ArgumentError) { Sidebar::Trigger.new(as_child: :a).then { |t| provider { render(t) } } }
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
    assert_includes button["class"], "h-12"
    assert_includes button["class"], "p-4"
    assert_not_includes button["class"], " p-2 "
    link = fragment(provider do
      render(Sidebar::MenuButton.new(as_child: :a, href: "#")) do
        "x"
      end
    end).at_css("a[data-slot=sidebar-menu-button]")

    assert_equal "false", link["data-active"]
    assert_raises(ArgumentError) { Sidebar::MenuButton.new(size: "huge") }
    assert_includes Sidebar::MenuButton.variants(size: "sm"), "h-7 text-xs"
  end

  test "menu button tooltip becomes a tooltip trigger and a content hidden while expanded" do
    html = provider { render(Sidebar::MenuButton.new(tooltip: "Home")) { "x" } }
    doc = fragment(html)
    button = doc.at_css("button[data-slot=sidebar-menu-button]")

    assert_equal "closed", button["data-state"]
    assert_includes button["data-controller"], "shadcn--tooltip"
    content = doc.at_css("template div[data-slot=tooltip-content]")

    assert content.key?("hidden")
    assert_equal "right", JSON.parse(doc.at_css("template[data-options]")["data-options"])["side"]
    assert_equal "Home", content.text
    collapsed = fragment(provider(default_open: false) { render(Sidebar::MenuButton.new(tooltip: { children: "H", hidden: false })) })

    assert_not collapsed.at_css("template div[data-slot=tooltip-content]").key?("hidden")
    assert_nil collapsed.at_css("[data-shadcn--sidebar-tooltip]")
  end

  test "menu skeleton draws its width between 50 and 89 percent" do
    skeleton = fragment(provider { render(Sidebar::MenuSkeleton.new(show_icon: true)) })

    assert skeleton.at_css("[data-sidebar=menu-skeleton-icon]")
    assert_match(/--skeleton-width: (5\d|[6-8]\d)%/, skeleton.at_css("[data-sidebar=menu-skeleton-text]")["style"])
  end

  test "menu skeleton width is random by default" do
    widths = Array.new(8) { fragment(provider { render(Sidebar::MenuSkeleton.new) }).at_css("[data-sidebar=menu-skeleton-text]")["style"][/--skeleton-width: (\d+)%/, 1].to_i }

    assert(widths.all? { |w| (50..89).cover?(w) })
  end

  test "menu skeleton width can be pinned and the pin is always restored" do
    pinned = Sidebar::MenuSkeleton.with_pinned_width(70) { provider { render(Sidebar::MenuSkeleton.new) } }

    assert_includes fragment(pinned).at_css("[data-sidebar=menu-skeleton-text]")["style"], "--skeleton-width: 70%"
    assert_nil Thread.current[Sidebar::MenuSkeleton::PIN_KEY]

    assert_raises(RuntimeError) { Sidebar::MenuSkeleton.with_pinned_width(70) { raise "boom" } }
    assert_nil Thread.current[Sidebar::MenuSkeleton::PIN_KEY]
  end

  test "every DX helper renders the same HTML as the explicit class" do
    normalize = ->(html) { html.gsub(/--skeleton-width: \d+%/, "w").gsub(/(sheet|tooltip-content|tooltip-provider|sidebar)-\d+/, '\1') }
    HELPERS.each do |name, klass|
      explicit = provider { render(Sidebar.new) { render(klass.new) { "x" } } }
      helper = provider { render(Sidebar.new) { |sidebar| sidebar.public_send(name) { "x" } } }

      assert_equal normalize.call(explicit), normalize.call(helper), name.to_s
    end
    assert_respond_to Sidebar.new, :provider
  end
end
