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

  test "root is the controller host with the oracle attributes" do
    out = render_menu

    assert_match(/<nav [^>]*data-slot="navigation-menu"/, out)
    assert_includes out, 'aria-label="Main"'
    assert_includes out, 'dir="ltr"'
    assert_includes out, 'data-orientation="horizontal"'
    assert_includes out, 'data-viewport="true"'
    assert_includes out, 'data-controller="shadcn--navigation-menu"'
    assert_includes out, 'data-shadcn--navigation-menu-delay-duration-value="200"'
    assert_includes out, 'data-shadcn--navigation-menu-skip-delay-duration-value="300"'
    assert_includes out, "group/navigation-menu relative flex max-w-max"
  end

  test "root options and caller attrs win" do
    out = render_menu(root: { viewport: false, orientation: :vertical, dir: "rtl", class: "max-w-full", aria: { label: "Primary" },
                              id: "nav" })

    assert_includes out, 'data-viewport="false"'
    assert_includes out, 'data-orientation="vertical"'
    assert_includes out, 'dir="rtl"'
    assert_includes out, 'aria-label="Primary"'
    assert_includes out, 'id="nav"'
    assert_includes out, "max-w-full"
    assert_not_includes out, "max-w-max"
    assert_not_includes out, 'data-shadcn--navigation-menu-target="viewportTemplate"'
  end

  test "viewport and content ship inert templates" do
    out = render_menu(content: { force_mount: true, class: "p-4" })

    assert_includes out, 'data-shadcn--navigation-menu-target="viewportTemplate"'
    assert_match(/<template data-shadcn--navigation-menu-target="contentTemplate" data-value="docs" data-force-mount="true">/, out)
    assert_includes out, 'data-slot="navigation-menu-content"'
    assert_includes out, "p-4"
    assert_not_includes out, " p-2 pr-2.5 "
    assert_includes out, 'data-slot="navigation-menu-viewport"'
  end

  test "trigger wires state, ids and the chevron" do
    out = render_menu(root: { default_value: "docs" }, trigger: { class: "rounded-full", data: { testid: "t" } })

    assert_match(/<button [^>]*data-slot="navigation-menu-trigger"/, out)
    assert_includes out, 'data-state="open"'
    assert_includes out, 'aria-expanded="true"'
    assert_match(/aria-controls="navigation-menu-\d+-content-docs"/, out)
    assert_includes out, "lucide-chevron-down"
    assert_includes out, "rounded-full"
    assert_includes out, 'data-testid="t"'
  end

  test "closed trigger has no aria-controls and a disabled one is marked" do
    out = render_menu(trigger: { disabled: true })

    assert_includes out, 'data-state="closed"'
    assert_includes out, 'aria-expanded="false"'
    assert_not_includes out, "aria-controls"
    assert_match(/<button [^>]*disabled/, out)
    assert_includes out, 'data-disabled=""'
  end

  test "link is active only on request and as_child merges onto the child" do
    assert_not_includes render_menu, "aria-current"
    assert_includes render_menu(link: { active: true }), 'aria-current="page"'

    out = render_menu(link: { as_child: :span, class: "x" })

    assert_match(/<span [^>]*data-slot="navigation-menu-link"/, out)
  end

  test "trigger_style is the cva base merged with the caller class" do
    assert_includes NavigationMenu.trigger_style, "inline-flex h-9 w-max"
    assert_includes NavigationMenu.trigger_style(class: "h-10"), "h-10"
    assert_not_includes NavigationMenu.trigger_style(class: "h-10"), "h-9"
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
end
