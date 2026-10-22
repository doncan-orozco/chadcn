# frozen_string_literal: true

require "chadcn/test_case"
require "json"

class Chadcn::SonnerTest < Chadcn::TestCase
  def render_toaster(**props, &)
    Chadcn::Toaster.new(**props).call(&)
  end

  def render_toast(**props, &)
    Chadcn::Sonner::Toast.new(**props).call(&)
  end

  def value_of(html, name)
    CGI.unescapeHTML(html[/data-shadcn--sonner-#{name}-value="([^"]*)"/, 1].to_s)
  end

  test "Toaster is the Sonner::Toaster class" do
    assert_same Chadcn::Sonner::Toaster, Chadcn::Toaster
  end

  test "the Sonner root renders a Toaster and its generated helpers equal the explicit classes" do
    explicit = Class.new(Phlex::HTML) do
      def view_template
        render(Chadcn::Sonner::Toaster.new(position: "top-center")) { render Chadcn::Sonner::Toast.new(title: "Hi", type: :success) }
      end
    end.new.call
    helpers = Class.new(Phlex::HTML) do
      def view_template = render(Chadcn::Sonner.new(position: "top-center")) { |sonner| sonner.toast(title: "Hi", type: :success) }
    end.new.call

    assert_equal explicit, helpers
    assert_equal(%i[toast toaster], %i[toast toaster].select { |helper| Chadcn::Sonner.public_method_defined?(helper) })
  end

  test "renders sonner's live region section with the controller" do
    html = render_toaster

    assert_includes html, "<section"
    assert_includes html, 'aria-live="polite"'
    assert_includes html, 'aria-relevant="additions text"'
    assert_includes html, 'aria-atomic="false"'
    assert_includes html, 'tabindex="-1"'
    assert_includes html, 'aria-label="Notifications alt+T"'
    assert_includes html, 'data-controller="shadcn--sonner"'
    assert_includes html, 'id="toaster"'
  end

  test "the hotkey and the container label feed the aria-label like sonner does" do
    html = render_toaster(hotkey: %w[altKey KeyJ], container_aria_label: "Alerts")

    assert_includes html, 'aria-label="Alerts alt+J"'
    assert_equal %w[altKey KeyJ], JSON.parse(value_of(html, "hotkey"))
  end

  test "defaults mirror sonner and the shadcn wrapper" do
    html = render_toaster

    assert_equal "bottom-right", value_of(html, "position")
    assert_equal "system", value_of(html, "theme")
    assert_equal "3", value_of(html, "visible-toasts")
    assert_equal "14", value_of(html, "gap")
    assert_equal "toaster group", value_of(html, "class-name")
    assert_equal({ "--normal-bg" => "var(--popover)", "--normal-text" => "var(--popover-foreground)", "--normal-border" => "var(--border)",
                   "--border-radius" => "var(--radius)" }, JSON.parse(value_of(html, "style")))
    assert_not_includes html, "rich-colors-value", "an omitted rich_colors must leave data-rich-colors off the toasts, like an omitted prop"
  end

  test "string and symbol options are equivalent" do
    from_symbol = value_of(render_toaster(position: :top_center), "position")
    from_string = value_of(render_toaster(position: "top-center"), "position")

    assert_equal "top-center", from_symbol
    assert_equal from_symbol, from_string
  end

  test "options become controller values" do
    html = render_toaster(rich_colors: true, close_button: true, expand: true, invert: true, duration: 6000, gap: 20, dir: :rtl, theme: :dark,
                          offset: { bottom: 80 }, mobile_offset: 8, swipe_directions: %w[left], toaster_id: "main")

    assert_equal "true", value_of(html, "rich-colors")
    assert_equal "true", value_of(html, "close-button")
    assert_equal "6000", value_of(html, "duration")
    assert_equal "20", value_of(html, "gap")
    assert_equal "rtl", value_of(html, "dir")
    assert_equal "dark", value_of(html, "theme")
    assert_equal({ "bottom" => 80 }, JSON.parse(value_of(html, "offset")))
    assert_equal 8, JSON.parse(value_of(html, "mobile-offset"))
    assert_equal %w[left], JSON.parse(value_of(html, "swipe-directions"))
    assert_equal "main", value_of(html, "toaster-id")
  end

  test "toast_options use sonner's camelCase names" do
    html = render_toaster(toast_options: { duration: 1000, close_button: true, class: "x", description_class_name: "d",
                                           class_names: { close_button: "c", toast: "t" } })

    assert_equal({ "duration" => 1000, "closeButton" => true, "className" => "x", "descriptionClassName" => "d",
                   "classNames" => { "closeButton" => "c", "toast" => "t" } }, JSON.parse(value_of(html, "toast-options")))
  end

  test "caller class joins the shadcn list classes, attrs go on the section" do
    html = render_toaster(class: "extra", id: "my-toaster", data: { testid: "t" })

    assert_equal "toaster group extra", value_of(html, "class-name")
    assert_includes html, 'id="my-toaster"'
    assert_includes html, 'data-testid="t"'
  end

  test "style is merged over the theme variables and is the style of the lists" do
    style = JSON.parse(value_of(render_toaster(style: { "--normal-bg": "red" }), "style"))

    assert_equal "red", style["--normal-bg"]
    assert_equal "var(--popover-foreground)", style["--normal-text"]
  end

  test "renders the shadcn icons of every type as inert templates" do
    html = render_toaster

    { "success" => "lucide-circle-check", "info" => "lucide-info", "warning" => "lucide-triangle-alert", "error" => "lucide-octagon-x",
      "loading" => "lucide-loader-circle size-4 animate-spin" }.each do |type, icon|
      assert_match(/<template data-shadcn--sonner-icon="#{type}"><svg[^>]*class="lucide #{icon}[^"]*"/, html)
    end
    assert_includes html, 'data-shadcn--sonner-icon="close"'
    assert_includes html, '<line x1="18" y1="6" x2="6" y2="18"></line>'
  end

  test "icons can be replaced or switched off per type" do
    html = render_toaster(icons: { success: false, error: Chadcn::Icon.new("x", class: "size-3") })

    assert_match(%r{<template data-shadcn--sonner-icon="success" data-none(="")?></template>}, html)
    assert_match(/<template data-shadcn--sonner-icon="error"><svg[^>]*class="lucide lucide-x size-3"/, html)
  end

  test "flash becomes typed toast templates and skips blanks" do
    html = render_toaster(flash: { "notice" => "Saved", alert: "Nope", "custom" => "Hello", "empty" => "" })

    assert_includes html, '<template data-shadcn--sonner-toast="" data-type="success"><div data-title="">Saved</div></template>'
    assert_includes html, 'data-type="error"><div data-title="">Nope</div>'
    assert_includes html, '<template data-shadcn--sonner-toast=""><div data-title="">Hello</div></template>'
    assert_equal 3, html.scan("data-shadcn--sonner-toast=").size
  end

  test "toasts: and the block render Toast templates" do
    page = Class.new(Phlex::HTML) do
      def view_template
        render(Chadcn::Toaster.new(toasts: [ { title: "A", type: :info } ])) { render Chadcn::Sonner::Toast.new(title: "B") }
      end
    end
    html = page.new.call

    assert_includes html, 'data-type="info"><div data-title="">A</div>'
    assert_includes html, '<template data-shadcn--sonner-toast=""><div data-title="">B</div></template>'
  end

  test "Toast escapes title and description" do
    html = render_toast(title: "<b>Hi</b>", description: "<script>x</script>")

    assert_includes html, "&lt;b&gt;Hi&lt;/b&gt;"
    assert_includes html, "&lt;script&gt;x&lt;/script&gt;"
    assert_not_includes html, "<b>"
  end

  test "Toast serializes its options as data attributes" do
    html = render_toast(title: "T", type: :success, id: "u1", duration: :infinity, position: :top_left, dismissible: false, close_button: true,
                        icon: :none, action: { label: "Undo", event: "undo" }, cancel: { label: "No", href: "/x" }, toaster_id: "main", test_id: "ti")

    %w[data-type="success" data-id="u1" data-duration="Infinity" data-position="top-left" data-dismissible="false" data-close-button="true" data-icon="none"
       data-action-label="Undo" data-action-event="undo" data-cancel-label="No" data-cancel-href="/x" data-toaster-id="main" data-test-id="ti"].each do |attr|
      assert_includes html, attr
    end
  end

  test "Toast without options carries only the marker, the title is the block when no title: is given" do
    html = render_toast { "From block" }

    assert_equal '<template data-shadcn--sonner-toast=""><div data-title="">From block</div></template>', html
  end

  test "rich_colors false is sent as false, not dropped" do
    assert_equal "false", value_of(render_toaster(rich_colors: false), "rich-colors")
  end

  test "an unknown toast type is rejected" do
    error = assert_raises(ArgumentError) { render_toast(title: "T", type: "constructor") }

    assert_includes error.message, "unknown toast type"
  end

  test "flash values that are not strings are skipped" do
    html = render_toaster(flash: { "timedout" => true, "notice" => "Saved" })

    assert_equal 1, html.scan("data-shadcn--sonner-toast=").size
  end

  test "numeric duration" do
    assert_includes render_toast(title: "T", duration: 5000), 'data-duration="5000"'
  end

  test "ships no JavaScript dependency" do
    root = Chadcn.root
    controller = File.read(root.join("app/javascript/controllers/shadcn/sonner_controller.js"))
    primitive = File.read(root.join("app/javascript/shadcn/primitives/toast_stack.js"))

    imports = (controller + primitive).scan(/^import .* from "([^"]+)"/).flatten.uniq.sort

    assert_equal [ "@hotwired/stimulus", "shadcn/primitives/toast_stack" ], imports
    assert_empty Dir[root.join("vendor/javascript/*sonner*").to_s]
    assert_not_includes File.read(root.join("config/importmap.rb")), "sonner"
  end
end
