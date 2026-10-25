# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SheetTest < Chadcn::TestCase
  Sheet = Chadcn::Sheet

  HELPERS = {
    trigger: Sheet::Trigger, close: Sheet::Close, content: Sheet::Content, header: Sheet::Header,
    footer: Sheet::Footer, title: Sheet::Title, description: Sheet::Description
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def sheet(root: {}, content: {})
    render_view do
      render(Sheet.new(**root)) do
        render(Sheet::Trigger.new) { "Open" }
        render(Sheet::Content.new(**content)) do
          render(Sheet::Title.new) { "Title" }
          render(Sheet::Description.new) { "Description" }
        end
      end
    end
  end

  test "host carries the controller and the closed parts live in a template" do
    doc = fragment(sheet)
    host = doc.at_css("[data-controller=chadcn--sheet]")

    assert_equal "display: contents", host["style"]
    assert_nil host["data-slot"]
    assert_equal "false", host["data-chadcn--sheet-open-value"]
    assert_equal 1, host.css("[data-slot=sheet-content]").size
    assert host.at_css("template [data-slot=sheet-overlay]")
    assert_equal "sheet-trigger", host.at_css("button")["data-slot"]
  end

  test "each side maps to its classes and an unknown side raises" do
    { "right" => "right-0", "left" => "left-0", "top" => "top-0", "bottom" => "bottom-0" }.each do |side, token|
      assert_includes fragment(sheet(content: { side: side.to_sym })).at_css("[data-slot=sheet-content]")["class"], token
    end
    error = assert_raises(ArgumentError) { sheet(content: { side: "middle" }) }

    assert_match(/side must be one of right, left, top, bottom, got "middle"/, error.message)
  end

  test "x close has no data-slot, content merges class and aria ids" do
    doc = fragment(sheet(content: { class: "w-96", aria: { describedby: "x" } }))
    content = doc.at_css("[data-slot=sheet-content]")

    assert_includes content["class"], "w-96"
    assert_equal "x sheet-1-description", content["aria-describedby"]
    assert_equal "sheet-1-title", content["aria-labelledby"]
    close = content.at_css("button")

    assert_nil close["data-slot"]
    assert_equal "Close", close.at_css(".sr-only").text
  end

  test "every DX helper renders the same HTML as the explicit class" do
    HELPERS.each do |name, klass|
      explicit = render_view { render(Sheet.new) { render(Sheet::Content.new) { render(klass.new) { "x" } } } }
      helper = render_view { render(Sheet.new) { |s| s.content { s.public_send(name) { "x" } } } }

      assert_equal explicit, helper, name.to_s
    end
  end

  test "root attributes and options land on the host" do
    host = fragment(sheet(root: { default_open: true, modal: false, class: "x-root", data: { foo: "bar" } })).at_css("[data-controller=chadcn--sheet]")

    assert_includes host["class"], "x-root"
    assert_equal "bar", host["data-foo"]
    assert_equal "true", host["data-chadcn--sheet-open-value"]
    assert_equal "false", host["data-chadcn--sheet-controlled-value"]
    assert_equal "false", host["data-chadcn--sheet-modal-value"]
  end

  test "close_label names the x button and show_close_button false removes it" do
    content = fragment(sheet(content: { close_label: "Fermer" })).at_css("[data-slot=sheet-content]")

    assert_equal "Fermer", content.at_css("button .sr-only").text
    assert_nil fragment(sheet(content: { show_close_button: false })).at_css("[data-slot=sheet-content] button")
  end

  test "force_mount is accepted and ignored on content and overlay" do
    plain = render_view { render(Sheet.new) { render(Sheet::Content.new) { render(Sheet::Overlay.new) } } }
    forced = render_view { render(Sheet.new) { render(Sheet::Content.new(force_mount: true)) { render(Sheet::Overlay.new(force_mount: true)) } } }

    assert_equal plain, forced
  end

  test "parts merge their class and attributes" do
    html = render_view do
      render(Sheet.new(default_open: true)) do
        render(Sheet::Content.new(class: "x-content")) do
          render(Sheet::Header.new(class: "x-header")) { "H" }
          render(Sheet::Title.new(class: "x-title")) { "T" }
          render(Sheet::Description.new(class: "x-description")) { "D" }
          render(Sheet::Footer.new(class: "x-footer")) { "F" }
          render(Sheet::Close.new(class: "x-close", id: "c")) { "C" }
        end
      end
    end
    doc = fragment(html)

    %w[content header title description footer].each { |slot| assert_includes doc.at_css("[data-slot=sheet-#{slot}]")["class"], "x-#{slot}", slot }
    assert_includes doc.at_css("#c")["class"], "x-close"
  end

  test "parts raise a clear ArgumentError outside the root" do
    %i[Trigger Content Overlay Portal Title Description].each do |part|
      error = assert_raises(ArgumentError, part.to_s) { render_view { render(Sheet.const_get(part).new) } }

      assert_match(/must be used within Sheet/, error.message, part.to_s)
    end
  end

  test "Close renders outside the root without raising" do
    out = render_view { render(Sheet::Close.new) { "C" } }

    assert_includes out, "data-slot=\"sheet-close\""
  end

  test "as_child renders the trigger onto the given element" do
    out = render_view do
      render(Sheet.new) do
        render(Sheet::Trigger.new(as_child: :a, href: "/x", class: "t")) { "Open" }
      end
    end
    trigger = Nokogiri::HTML5.fragment(out).at_css("[data-slot*=trigger]")

    assert_equal "a", trigger.name
    assert_equal "/x", trigger["href"]
    assert_includes trigger["class"], "t"
  end

  test "id names the content and the trigger controls it while open" do
    doc = fragment(sheet(root: { id: "article-settings", default_open: true }))
    content = doc.at_css("[data-slot=sheet-content]")

    assert_equal "article-settings", content["id"]
    assert_equal "article-settings-title", content["aria-labelledby"]
    assert_equal "article-settings-description", content["aria-describedby"]
    assert_equal "article-settings", doc.at_css("[data-slot=sheet-trigger]")["aria-controls"]
    assert_equal "article-settings", doc.at_css("[data-controller=chadcn--sheet]")["data-chadcn--sheet-id-value"]
    assert_nil doc.at_css("[data-controller=chadcn--sheet]")["id"]
  end

  test "without id the content is sheet-1 and the trigger controls it" do
    doc = fragment(sheet(root: { default_open: true }))

    assert_equal "sheet-1", doc.at_css("[data-slot=sheet-content]")["id"]
    assert_equal "sheet-1", doc.at_css("[data-slot=sheet-trigger]")["aria-controls"]
    assert_equal "sheet-1", doc.at_css("template")["data-chadcn--dialog-template"]
  end
end
