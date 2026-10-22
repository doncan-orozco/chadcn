# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::MessageTest < Chadcn::TestCase
  PARTS = { group: "group", avatar: "avatar", content: "content", footer: "footer", header: "header" }.freeze

  def html(**, &block)
    Chadcn::Message.new(**).call(&block || proc { |_| "Hi" })
  end

  test "root renders slot, align default and symbol align" do
    assert_includes html, 'data-slot="message"'
    assert_includes html, 'data-align="start"'
    assert_includes html(align: :end), 'data-align="end"'
    assert_includes html(align: nil), 'data-align="start"'
  end

  test "unknown align raises" do
    assert_raises(ArgumentError) { html(align: :middle) }
  end

  test "class merges last, attrs pass through and data-align attr wins" do
    out = html(class: "gap-4", id: "m", data: { align: "end" })

    assert_not_includes out, "gap-2"
    assert_includes out, 'id="m"'
    assert_includes out, 'data-align="end"'
  end

  test "every part renders its slot" do
    PARTS.each_value do |name|
      klass = Chadcn::Message.const_get(name.capitalize)

      assert_includes klass.new(id: "x").call { "t" }, %(data-slot="message-#{name}"), name
    end
  end

  test "every DX helper renders the same HTML as the explicit class" do
    PARTS.each do |helper, name|
      klass = Chadcn::Message.const_get(name.capitalize)
      via_helper = Chadcn::Message.new.call { |m| m.public_send(helper, class: "x") { "t" } }
      explicit = Chadcn::Message.new.call { |m| m.render klass.new(class: "x") { "t" } }

      assert_equal explicit, via_helper, helper.to_s
    end
  end
end
