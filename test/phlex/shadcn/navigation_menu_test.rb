# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::NavigationMenuTest < Phlex::Shadcn::TestCase
  NavigationMenu = Phlex::Shadcn::NavigationMenu

  def render_menu(root: {}, trigger: {}, content: {}, link: {}, item: {})
    Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render NavigationMenu.new(**root) do
          render NavigationMenu::List.new do
            render NavigationMenu::Item.new(value: "docs", **item) do
              render NavigationMenu::Trigger.new(**trigger) { plain "Docs" }
              render NavigationMenu::Content.new(**content) do
                render NavigationMenu::Link.new(href: "#intro", **link) { plain "Intro" }
              end
            end
          end
        end
      end
    end.new.call
  end

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def part(html, slot) = fragment(html).at_css("[data-slot=#{slot}]")

  def template_target(html, target) = fragment(html).at_css("template[data-shadcn--navigation-menu-target=#{target}]")

  test "root is the controller host with the oracle attributes" do
    nav = part(render_menu, "navigation-menu")

    assert_equal "nav", nav.name
    assert_equal "Main", nav["aria-label"]
    assert_equal "ltr", nav["dir"]
    assert_equal "horizontal", nav["data-orientation"]
    assert_equal "true", nav["data-viewport"]
    assert_equal "shadcn--navigation-menu", nav["data-controller"]
    assert_equal "200", nav["data-shadcn--navigation-menu-delay-duration-value"]
    assert_equal "300", nav["data-shadcn--navigation-menu-skip-delay-duration-value"]
    %w[group/navigation-menu relative flex max-w-max].each { |token| assert_includes nav["class"].split, token }
  end

  test "root options and caller attrs win" do
    out = render_menu(root: { viewport: false, orientation: :vertical, dir: "rtl", class: "max-w-full", aria: { label: "Primary" },
                              id: "nav" })
    nav = part(out, "navigation-menu")

    assert_equal "false", nav["data-viewport"]
    assert_equal "vertical", nav["data-orientation"]
    assert_equal "rtl", nav["dir"]
    assert_equal "Primary", nav["aria-label"]
    assert_equal "nav", nav["id"]
    assert_includes nav["class"].split, "max-w-full"
    assert_not_includes nav["class"].split, "max-w-max"
    assert_nil template_target(out, "viewportTemplate")
  end

  test "viewport and content ship inert templates" do
    out = render_menu(content: { force_mount: true, class: "p-4" })
    content_template = template_target(out, "contentTemplate")
    content = content_template.at_css("[data-slot=navigation-menu-content]")

    assert_equal "docs", content_template["data-value"]
    assert_equal "true", content_template["data-force-mount"]
    assert_includes content["class"].split, "p-4"
    assert_not_includes content["class"].split, "p-2"
    assert template_target(out, "viewportTemplate").at_css("[data-slot=navigation-menu-viewport]")
  end

  test "trigger wires state, ids and the chevron" do
    trigger = part(render_menu(root: { default_value: "docs" }, trigger: { class: "rounded-full", data: { testid: "t" } }),
                   "navigation-menu-trigger")

    assert_equal "button", trigger.name
    assert_equal "open", trigger["data-state"]
    assert_equal "true", trigger["aria-expanded"]
    assert_match(/\Anavigation-menu-\d+-content-docs\z/, trigger["aria-controls"])
    assert trigger.at_css("svg.lucide-chevron-down")
    assert_includes trigger["class"].split, "rounded-full"
    assert_equal "t", trigger["data-testid"]
  end

  test "closed trigger has no aria-controls and a disabled one is marked" do
    trigger = part(render_menu(trigger: { disabled: true }), "navigation-menu-trigger")

    assert_equal "closed", trigger["data-state"]
    assert_equal "false", trigger["aria-expanded"]
    assert_not trigger.key?("aria-controls")
    assert trigger.key?("disabled")
    assert_equal "", trigger["data-disabled"]
  end

  test "link is active only on request and as_child merges onto the child" do
    assert_not part(render_menu, "navigation-menu-link").key?("aria-current")
    assert_equal "page", part(render_menu(link: { active: true }), "navigation-menu-link")["aria-current"]

    span = part(render_menu(link: { as_child: :span, class: "zz-link" }), "navigation-menu-link")

    assert_equal "span", span.name
    assert_includes span["class"].split, "zz-link"
  end

  test "trigger_style is the cva base merged with the caller class" do
    %w[inline-flex h-9 w-max].each { |token| assert_includes NavigationMenu.trigger_style.split, token }

    merged = NavigationMenu.trigger_style(class: "h-10").split

    assert_includes merged, "h-10"
    assert_not_includes merged, "h-9"
  end

  test "parts outside the root raise" do
    assert_raises(ArgumentError) { NavigationMenu::Trigger.new.call }
  end

  test "every helper of the yielded root renders like the explicit part" do
    %i[list item content trigger link indicator viewport].each { |helper| assert_respond_to NavigationMenu.new, helper }

    explicit = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render NavigationMenu.new(viewport: false) do
          render NavigationMenu::List.new do
            render(NavigationMenu::Item.new(value: "a")) do
              render(NavigationMenu::Trigger.new) { plain "A" }
              render(NavigationMenu::Content.new) { render(NavigationMenu::Link.new(href: "#a")) { plain "L" } }
            end
          end
          render NavigationMenu::Indicator.new
          render NavigationMenu::Viewport.new
        end
      end
    end.new.call
    helpers = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render NavigationMenu.new(viewport: false) do |menu|
          menu.list do
            menu.item(value: "a") do
              menu.trigger { plain "A" }
              menu.content { menu.link(href: "#a") { plain "L" } }
            end
          end
          menu.indicator
          menu.viewport
        end
      end
    end.new.call

    assert_equal explicit, helpers
  end

  test "value makes the menu controlled and opens the matching item" do
    out = render_menu(root: { value: "docs" })
    nav = part(out, "navigation-menu")

    assert_equal "true", nav["data-shadcn--navigation-menu-controlled-value"]
    assert_equal "docs", nav["data-shadcn--navigation-menu-value-value"]
    assert_equal "true", part(out, "navigation-menu-trigger")["aria-expanded"]

    closed = render_menu(root: { value: "", default_value: "docs" })

    assert_equal "true", part(closed, "navigation-menu")["data-shadcn--navigation-menu-controlled-value"]
    assert_equal "false", part(closed, "navigation-menu-trigger")["aria-expanded"]
  end

  test "default_value is uncontrolled" do
    nav = part(render_menu(root: { default_value: "docs" }), "navigation-menu")

    assert_equal "false", nav["data-shadcn--navigation-menu-controlled-value"]
    assert_equal "docs", nav["data-shadcn--navigation-menu-value-value"]
  end

  test "delays, activation mode and orientation reach the controller values" do
    nav = part(render_menu(root: { delay_duration: 10, skip_delay_duration: 20, activation_mode: :manual, orientation: "vertical" }),
               "navigation-menu")

    assert_equal "10", nav["data-shadcn--navigation-menu-delay-duration-value"]
    assert_equal "20", nav["data-shadcn--navigation-menu-skip-delay-duration-value"]
    assert_equal "manual", nav["data-shadcn--navigation-menu-activation-mode-value"]
    assert_equal "vertical", nav["data-shadcn--navigation-menu-orientation-value"]
    assert_equal "automatic", part(render_menu, "navigation-menu")["data-shadcn--navigation-menu-activation-mode-value"]
    assert_equal "horizontal", part(render_menu(root: { orientation: "diagonal" }), "navigation-menu")["data-orientation"]
  end

  test "documents current behavior: an unknown activation mode is forwarded as given (Tabs normalizes, the menu does not)" do
    nav = part(render_menu(root: { activation_mode: "sideways" }), "navigation-menu")

    assert_equal "sideways", nav["data-shadcn--navigation-menu-activation-mode-value"]
  end

  test "dir comes from the direction provider unless set" do
    inherited = render_view do
      render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(NavigationMenu.new(viewport: false)) }
    end
    nav = part(inherited, "navigation-menu")

    assert_equal "rtl", nav["dir"]
    assert_equal "rtl", nav["data-shadcn--navigation-menu-dir-value"]

    explicit = render_view do
      render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(NavigationMenu.new(viewport: false, dir: "ltr")) }
    end
    local = part(explicit, "navigation-menu")

    assert_equal "ltr", local["dir"]
    assert_equal "ltr", local["data-shadcn--navigation-menu-dir-value"]
  end

  test "list and item render ul and li, or the as_child element, with caller attrs" do
    out = render_view do
      render NavigationMenu.new(viewport: false) do
        render(NavigationMenu::List.new(class: "gap-4", id: "l")) { render(NavigationMenu::Item.new(class: "x", id: "i")) { plain "a" } }
        render(NavigationMenu::List.new(as_child: :ol)) { render(NavigationMenu::Item.new(as_child: :div)) { plain "b" } }
      end
    end
    doc = Nokogiri::HTML5.fragment(out)

    assert_includes doc.at_css("ul#l")["class"].split, "gap-4"
    %w[relative x].each { |token| assert_includes doc.at_css("li#i")["class"].split, token }
    assert_equal "navigation-menu-list", doc.at_css("ol")["data-slot"]
    assert_equal "navigation-menu-item", doc.at_css("div[data-slot=navigation-menu-item]")["data-slot"]
  end

  test "an item without value gets a generated one that links trigger and content" do
    out = render_view do
      render NavigationMenu.new(viewport: false) do
        render(NavigationMenu::Item.new) do
          render(NavigationMenu::Trigger.new) { plain "A" }
          render(NavigationMenu::Content.new) { plain "c" }
        end
      end
    end
    value = template_target(out, "contentTemplate")["data-value"]

    assert_match(/\Anavigation-menu-\d+-item-\d+\z/, value)
    assert_equal "navigation-menu-#{value[/\d+/]}-trigger-#{value}", part(out, "navigation-menu-trigger")["id"]
  end

  test "content as_child merges onto the child and is a template" do
    out = render_menu(content: { as_child: :section, class: "p-9" })
    section = Nokogiri::HTML5.fragment(out).at_css("template[data-shadcn--navigation-menu-target=contentTemplate]").at_css("section")

    assert_equal "navigation-menu-content", section["data-slot"]
    assert_includes section["class"].split, "p-9"
  end

  test "viewport and indicator take force_mount and caller attrs" do
    out = render_view do
      render NavigationMenu.new(viewport: false) do
        render NavigationMenu::List.new
        render NavigationMenu::Indicator.new(force_mount: true, class: "bg-red-500", id: "ind")
        render NavigationMenu::Viewport.new(force_mount: true, class: "mt-9", id: "vp")
      end
    end
    doc = Nokogiri::HTML5.fragment(out)
    indicator = doc.at_css("template[data-shadcn--navigation-menu-target=indicatorTemplate]")
    viewport = doc.at_css("template[data-shadcn--navigation-menu-target=viewportTemplate]")

    assert_equal "true", indicator["data-force-mount"]
    assert_equal "true", viewport["data-force-mount"]
    assert_equal "ind", indicator.at_css("[data-slot=navigation-menu-indicator]")["id"]
    assert_includes indicator.at_css("[data-slot=navigation-menu-indicator]")["class"].split, "bg-red-500"
    assert_includes viewport.at_css("[data-slot=navigation-menu-viewport]")["class"].split, "mt-9"
    assert_raises(ArgumentError) { NavigationMenu::Indicator.new.call }
    assert_raises(ArgumentError) { NavigationMenu::Viewport.new.call }
  end

  test "content outside an item raises and a standalone link renders" do
    assert_raises(ArgumentError) { render_view { render(NavigationMenu.new) { render NavigationMenu::Content.new } } }
    assert_equal "/x", fragment(NavigationMenu::Link.new(href: "/x").call { "x" }).at_css("a")["href"]
  end
end
