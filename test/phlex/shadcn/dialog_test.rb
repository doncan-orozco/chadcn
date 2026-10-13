# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::DialogTest < Phlex::Shadcn::TestCase
  Dialog = Phlex::Shadcn::Dialog

  HELPERS = {
    close: Dialog::Close, content: Dialog::Content, description: Dialog::Description, footer: Dialog::Footer,
    header: Dialog::Header, overlay: Dialog::Overlay, portal: Dialog::Portal, title: Dialog::Title, trigger: Dialog::Trigger
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def dialog(root: {}, content: {}, footer: {}, &body)
    render_view do
      render(Dialog.new(**root)) do
        render(Dialog::Trigger.new(as_child: Phlex::Shadcn::Button.new(variant: "outline"))) { "Open" }
        render(Dialog::Content.new(**content)) do
          instance_exec(&body) if body
          render(Dialog::Footer.new(**footer)) { "Actions" }
        end
      end
    end
  end

  test "host carries the controller and the closed parts live in a template" do
    doc = fragment(dialog)
    host = doc.at_css("[data-controller=shadcn--dialog]")

    assert_equal "display: contents", host["style"]
    assert_nil host["data-slot"]
    assert_equal "false", host["data-shadcn--dialog-open-value"]
    assert_equal "true", host["data-shadcn--dialog-modal-value"]

    trigger = host.at_css("[data-shadcn--dialog-part=trigger]")

    assert_equal "dialog-trigger", trigger["data-slot"]
    assert_equal "outline", trigger["data-variant"]
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "dialog", trigger["aria-haspopup"]
    assert_nil trigger["aria-controls"]

    template = host.at_css("template[data-shadcn--dialog-template]")

    assert template.at_css("[data-slot=dialog-overlay][data-state=open]")
    content = template.at_css("[data-slot=dialog-content]")

    assert_equal "dialog", content["role"]
    assert_equal "-1", content["tabindex"]
    assert_includes content["class"], "sm:max-w-lg"
    assert_equal 1, host.css("[data-slot=dialog-content]").size
  end

  test "x close button is the last child of the content and show_close_button false removes it" do
    content = fragment(dialog).at_css("[data-slot=dialog-content]")
    close = content.at_css("> [data-slot=dialog-close]")

    assert_equal close, content.element_children.last
    assert_equal "Close", close.at_css("span.sr-only").text
    assert close.at_css("svg.lucide-x")
    assert_nil close["data-state"]
    assert_nil fragment(dialog(content: { show_close_button: false })).at_css("[data-slot=dialog-close]")
  end

  test "open dialog is reflected on the trigger" do
    trigger = fragment(dialog(root: { default_open: true })).at_css("[data-shadcn--dialog-part=trigger]")

    assert_equal "true", trigger["aria-expanded"]
    assert_equal "open", trigger["data-state"]
    assert trigger["aria-controls"]
  end

  test "controlled open is flagged on the host" do
    host = fragment(dialog(root: { open: true })).at_css("[data-controller=shadcn--dialog]")

    assert_equal "true", host["data-shadcn--dialog-controlled-value"]
    assert_equal "true", host["data-shadcn--dialog-open-value"]
  end

  test "non modal dialog renders no overlay" do
    doc = fragment(dialog(root: { modal: false }))

    assert_nil doc.at_css("[data-slot=dialog-overlay]")
    assert doc.at_css("[data-slot=dialog-content]")
  end

  test "labelledby and describedby follow the rendered title and description" do
    plain = fragment(dialog).at_css("[data-slot=dialog-content]")

    assert_nil plain["aria-labelledby"]
    assert_nil plain["aria-describedby"]

    content = fragment(dialog(content: { aria: { describedby: "extra" } }) do
      render(Dialog::Title.new) { "Edit" }
      render(Dialog::Description.new) { "Desc" }
    end).at_css("[data-slot=dialog-content]")
    title = content.at_css("[data-slot=dialog-title]")
    description = content.at_css("[data-slot=dialog-description]")

    assert_equal "h2", title.name
    assert_equal title["id"], content["aria-labelledby"]
    assert_equal "extra #{description['id']}", content["aria-describedby"]
  end

  test "content merges class, attributes and as_child" do
    content = fragment(dialog(content: { class: "rounded-xl", "data-testid": "x",
                                         aria: { label: "L" } })).at_css("[data-slot=dialog-content]")

    assert_includes content["class"], "rounded-xl"
    refute_includes content["class"], "rounded-lg"
    assert_equal "x", content["data-testid"]
    assert_equal "L", content["aria-label"]

    title = fragment(dialog { render(Dialog::Title.new(as_child: :h3)) { "T" } }).at_css("[data-slot=dialog-title]")

    assert_equal "h3", title.name
  end

  test "footer show_close_button appends an outline button close" do
    close = fragment(dialog(footer: { show_close_button: true })).at_css("[data-slot=dialog-footer] > button")

    assert_equal "button", close["data-slot"]
    assert_equal "outline", close["data-variant"]
    assert_equal "Close", close.text
    assert_nil fragment(dialog).at_css("[data-slot=dialog-footer] > button")
  end

  test "overlay standalone inside a portal" do
    html = render_view do
      render(Dialog.new(default_open: true)) { render(Dialog::Portal.new) { render(Dialog::Overlay.new(class: "bg-black/80")) } }
    end
    overlay = fragment(html).at_css("template [data-slot=dialog-overlay]")

    assert_includes overlay["class"], "bg-black/80"
    assert_equal "pointer-events: auto", overlay["style"]
  end

  test "every helper exists on the root and renders the same HTML as the explicit call" do
    explicit = render_view { render(Dialog.new) { render(Dialog::Header.new(class: "x")) { "H" } } }
    helper = render_view { render(Dialog.new) { |d| d.header(class: "x") { "H" } } }

    assert_equal explicit, helper
    HELPERS.each do |name, part|
      assert Dialog.public_method_defined?(name), "missing helper ##{name}"
      assert_equal part, Dialog.const_get(name.to_s.split("_").map(&:capitalize).join)
    end
  end
end
