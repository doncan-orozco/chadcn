# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SheetTest < Phlex::Shadcn::TestCase
  Sheet = Phlex::Shadcn::Sheet

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
    host = doc.at_css("[data-controller=shadcn--sheet]")

    assert_equal "display: contents", host["style"]
    assert_nil host["data-slot"]
    assert_equal "false", host["data-shadcn--sheet-open-value"]
    assert_equal 1, host.css("[data-slot=sheet-content]").size
    assert host.at_css("template [data-slot=sheet-overlay]")
    assert_equal "sheet-trigger", host.at_css("button")["data-slot"]
  end

  test "each side maps to its classes and an unknown side raises" do
    { "right" => "right-0", "left" => "left-0", "top" => "top-0", "bottom" => "bottom-0" }.each do |side, token|
      assert_includes fragment(sheet(content: { side: side.to_sym })).at_css("[data-slot=sheet-content]")["class"], token
    end
    assert_raises(ArgumentError) { sheet(content: { side: "middle" }) }
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
end
