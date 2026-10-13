# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::AlertTest < Phlex::Shadcn::TestCase
  def html(**, &block)
    Phlex::Shadcn::Alert.new(**).call(&block || proc { |_| "Body" })
  end

  test "renders each variant with slot and role" do
    Phlex::Shadcn::Alert::VARIANTS.each_key do |v|
      out = html(variant: v)

      assert_includes out, 'data-slot="alert"'
      assert_includes out, 'role="alert"'
    end
    assert_includes html(variant: :destructive), "text-destructive"
    assert_includes html(variant: nil), "bg-card text-card-foreground"
  end

  test "class merges last, attrs pass through and role is overridable" do
    out = html(class: "rounded-none", id: "a", role: "status", data: { x: "1" })

    assert_includes out, "rounded-none"
    assert_not_includes out, "rounded-lg"
    assert_includes out, 'id="a"'
    assert_includes out, 'role="status"'
    assert_includes out, 'data-x="1"'
  end

  test "unknown variant raises" do
    assert_raises(ArgumentError) { html(variant: :nope) }
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html do |a|
      a.title(class: "t") { "T" }
      a.description { "D" }
    end
    explicit = html do |a|
      a.render Phlex::Shadcn::Alert::Title.new(class: "t") { "T" }
      a.render(Phlex::Shadcn::Alert::Description.new { "D" })
    end

    assert_equal explicit, helpers
    assert_includes helpers, 'data-slot="alert-title"'
    assert_includes helpers, 'data-slot="alert-description"'
  end
end
